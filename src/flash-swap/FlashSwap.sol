// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

import { IMultipool } from "../interfaces/IMultipool.sol";


contract FlashSwap {

    constructor() {
        _disableInitializers();
    }


    /**
      * @notice Fills an order and transfers making amount to a specified target.
      * @dev If the target is zero assigns it the caller's address.
      * The function flow is as follows:
      * 1. Validate order
      * 2. Call maker pre-interaction
      * 3. Transfer maker asset to taker
      * 4. Call taker interaction
      * 5. Transfer taker asset to maker
      * 5. Call maker post-interaction
      * 6. Emit OrderFilled event
      * @param order The order details.
      * @param orderHash The hash of the order.
      * @param extension The extension calldata of the order.
      * @param remainingMakingAmount The remaining amount to be filled.
      * @param amount The order amount.
      * @param takerTraits The taker preferences for the order.
      * @param target The address to which the order is filled.
      * @param interaction The interaction calldata.
      * @return makingAmount The computed amount that the maker will get.
      * @return takingAmount The computed amount that the taker will send.
      */
    function _fill(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        uint256 remainingMakingAmount,
        uint256 amount,
        TakerTraits takerTraits,
        address target,
        bytes calldata extension,
        bytes calldata interaction
    ) private whenNotPaused() returns(uint256 makingAmount, uint256 takingAmount) {
        // Validate order
        {
            (bool valid, bytes4 validationResult) = order.isValidExtension(extension);
            if (!valid) {
                // solhint-disable-next-line no-inline-assembly
                assembly ("memory-safe") {
                    mstore(0, validationResult)
                    revert(0, 4)
                }
            }
        }
        if (!order.makerTraits.isAllowedSender(msg.sender)) revert PrivateOrder();
        if (order.makerTraits.isExpired()) revert OrderExpired();
        if (order.makerTraits.needCheckEpochManager()) {
            if (order.makerTraits.useBitInvalidator()) revert EpochManagerAndBitInvalidatorsAreIncompatible();
            if (!epochEquals(order.maker.get(), order.makerTraits.series(), order.makerTraits.nonceOrEpoch())) revert WrongSeriesNonce();
        }

        // Check if orders predicate allows filling
        if (extension.length > 0) {
            bytes calldata predicate = extension.predicate();
            if (predicate.length > 0) {
                if (!checkPredicate(predicate)) revert PredicateIsNotTrue();
            }
        }

        // Compute maker and taker assets amount
        if (takerTraits.isMakingAmount()) {
            makingAmount = Math.min(amount, remainingMakingAmount);
            takingAmount = order.calculateTakingAmount(extension, makingAmount, remainingMakingAmount, orderHash);

            uint256 threshold = takerTraits.threshold();
            if (threshold > 0) {
                // Check rate: takingAmount / makingAmount <= threshold / amount
                if (amount == makingAmount) {  // Gas optimization, no SafeMath.mul()
                    if (takingAmount > threshold) revert TakingAmountTooHigh();
                } else {
                    if (takingAmount * amount > threshold * makingAmount) revert TakingAmountTooHigh();
                }
            }
        }
        else {
            takingAmount = amount;
            makingAmount = order.calculateMakingAmount(extension, takingAmount, remainingMakingAmount, orderHash);
            if (makingAmount > remainingMakingAmount) {
                // Try to decrease taking amount because computed making amount exceeds remaining amount
                makingAmount = remainingMakingAmount;
                takingAmount = order.calculateTakingAmount(extension, makingAmount, remainingMakingAmount, orderHash);
                if (takingAmount > amount) revert TakingAmountExceeded();
            }

            uint256 threshold = takerTraits.threshold();
            if (threshold > 0) {
                // Check rate: makingAmount / takingAmount >= threshold / amount
                if (amount == takingAmount) { // Gas optimization, no SafeMath.mul()
                    if (makingAmount < threshold) revert MakingAmountTooLow();
                } else {
                    if (makingAmount * amount < threshold * takingAmount) revert MakingAmountTooLow();
                }
            }
        }
        if (!order.makerTraits.allowPartialFills() && makingAmount != order.makingAmount) revert PartialFillNotAllowed();
        unchecked { if (makingAmount * takingAmount == 0) revert SwapWithZeroAmount(); }

        // Invalidate order depending on makerTraits
        if (order.makerTraits.useBitInvalidator()) {
            _bitInvalidator[order.maker.get()].checkAndInvalidate(order.makerTraits.nonceOrEpoch());
        } else {
            _remainingInvalidator[order.maker.get()][orderHash] = RemainingInvalidatorLib.remains(remainingMakingAmount, makingAmount);
        }

        // Pre interaction, where maker can prepare funds interactively
        if (order.makerTraits.needPreInteractionCall()) {
            bytes calldata data = extension.preInteractionTargetAndData();
            address listener = order.maker.get();
            if (data.length > 19) {
                listener = address(bytes20(data));
                data = data[20:];
            }
            IPreInteraction(listener).preInteraction(
                order, extension, orderHash, msg.sender, makingAmount, takingAmount, remainingMakingAmount, data
            );
        }

        // Maker => Taker
        {
            bool needUnwrap = order.makerAsset.get() == address(_WETH) && takerTraits.unwrapWeth();
            address receiver = needUnwrap ? address(this) : target;
            if (order.makerTraits.usePermit2()) {
                if (extension.makerAssetSuffix().length > 0) revert InvalidPermit2Transfer();
                IERC20(order.makerAsset.get()).safeTransferFromPermit2(order.maker.get(), receiver, makingAmount);
            } else {
                if (!_callTransferFromWithSuffix(
                    order.makerAsset.get(),
                    order.maker.get(),
                    receiver,
                    makingAmount,
                    extension.makerAssetSuffix()
                )) revert TransferFromMakerToTakerFailed();
            }
            if (needUnwrap) {
                _WETH.safeWithdrawTo(makingAmount, target);
            }
        }

        if (interaction.length > 19) {
            // proceed only if interaction length is enough to store address
            ITakerInteraction(address(bytes20(interaction))).takerInteraction(
                order, extension, orderHash, msg.sender, makingAmount, takingAmount, remainingMakingAmount, interaction[20:]
            );
        }

        // Taker => Maker
        if (order.takerAsset.get() == address(_WETH) && msg.value > 0) {
            if (msg.value < takingAmount) revert Errors.InvalidMsgValue();
            if (msg.value > takingAmount) {
                unchecked {
                    // solhint-disable-next-line avoid-low-level-calls
                    (bool success, ) = msg.sender.call{value: msg.value - takingAmount}("");
                    if (!success) revert Errors.ETHTransferFailed();
                }
            }

            if (order.makerTraits.unwrapWeth()) {
                // solhint-disable-next-line avoid-low-level-calls
                (bool success, ) = order.getReceiver().call{value: takingAmount}("");
                if (!success) revert Errors.ETHTransferFailed();
            } else {
                _WETH.safeDeposit(takingAmount);
                _WETH.safeTransfer(order.getReceiver(), takingAmount);
            }
        } else {
            if (msg.value != 0) revert Errors.InvalidMsgValue();

            bool needUnwrap = order.takerAsset.get() == address(_WETH) && order.makerTraits.unwrapWeth();
            address receiver = needUnwrap ? address(this) : order.getReceiver();
            if (takerTraits.usePermit2()) {
                if (extension.takerAssetSuffix().length > 0) revert InvalidPermit2Transfer();
                IERC20(order.takerAsset.get()).safeTransferFromPermit2(msg.sender, receiver, takingAmount);
            } else {
                if (!_callTransferFromWithSuffix(
                    order.takerAsset.get(),
                    msg.sender,
                    receiver,
                    takingAmount,
                    extension.takerAssetSuffix()
                )) revert TransferFromTakerToMakerFailed();
            }

            if (needUnwrap) {
                _WETH.safeWithdrawTo(takingAmount, order.getReceiver());
            }
        }

        // Post interaction, where maker can handle funds interactively
        if (order.makerTraits.needPostInteractionCall()) {
            bytes calldata data = extension.postInteractionTargetAndData();
            address listener = order.maker.get();
            if (data.length > 19) {
                listener = address(bytes20(data));
                data = data[20:];
            }
            IPostInteraction(listener).postInteraction(
                order, extension, orderHash, msg.sender, makingAmount, takingAmount, remainingMakingAmount, data
            );
        }

        emit OrderFilled(orderHash, remainingMakingAmount - makingAmount);
    }
    

    /**
    * @notice Performs a swap, delegating all calls encoded in `data` to `executor`. See tests for usage examples.
    * @dev Router keeps 1 wei of every token on the contract balance for gas optimisations reasons.
    *      This affects first swap of every token by leaving 1 wei on the contract.
    * @param executor Aggregation executor that executes calls described in `data`.
    * @param desc Swap description.
    * @param data Encoded calls that `caller` should execute in between of swaps.
    * @return returnAmount Resulting token amount.
    * @return spentAmount Source token amount.
    */
    function swap(
        IAggregationExecutor executor,
        SwapDescription calldata desc,
        bytes calldata data
    )
        external
        payable
        whenNotPaused()
        returns (
            uint256 returnAmount,
            uint256 spentAmount
        )
    {
        if (desc.minReturnAmount == 0) revert ZeroMinReturn();

        IERC20 srcToken = desc.srcToken;
        IERC20 dstToken = desc.dstToken;

        bool srcETH = srcToken.isETH();
        if (desc.flags & _REQUIRES_EXTRA_ETH != 0) {
            if (msg.value <= (srcETH ? desc.amount : 0)) revert RouterErrors.InvalidMsgValue();
        } else {
            if (msg.value != (srcETH ? desc.amount : 0)) revert RouterErrors.InvalidMsgValue();
        }

        if (!srcETH) {
            srcToken.safeTransferFromUniversal(msg.sender, desc.srcReceiver, desc.amount, desc.flags & _USE_PERMIT2 != 0);
        }

        returnAmount = _execute(executor, msg.sender, desc.amount, data);
        spentAmount = desc.amount;

        if (desc.flags & _PARTIAL_FILL != 0) {
            uint256 unspentAmount = srcToken.uniBalanceOf(address(this));
            if (unspentAmount > 1) {
                // we leave 1 wei on the router for gas optimisations reasons
                unchecked { unspentAmount--; }
                spentAmount -= unspentAmount;
                srcToken.uniTransfer(payable(msg.sender), unspentAmount);
            }
            if (returnAmount * desc.amount < desc.minReturnAmount * spentAmount) revert RouterErrors.ReturnAmountIsNotEnough(returnAmount, desc.minReturnAmount * spentAmount / desc.amount);
        } else {
            if (returnAmount < desc.minReturnAmount) revert RouterErrors.ReturnAmountIsNotEnough(returnAmount, desc.minReturnAmount);
        }

        address payable dstReceiver = (desc.dstReceiver == address(0)) ? payable(msg.sender) : desc.dstReceiver;
        dstToken.uniTransfer(dstReceiver, returnAmount);
    }
}