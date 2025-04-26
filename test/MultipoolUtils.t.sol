// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../src/multipool/MultipoolRouter.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedType} from "../src/lib/Price.sol";
import {setBytes} from "../src/lib/Binary.sol";
import {OraclePrice} from "../src/types/OraclePrice.sol";
import {ReceiverData} from "../src/types/ReceiverData.sol";
import {IArcanumOracle} from "../src/interfaces/IArcanumOracle.sol";
import {IPriceAdapter} from "../src/interfaces/IPriceAdapter.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import {DummyOracle} from "../src/multipool/DummyOracle.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

function computeContractAddress(
    address factory,
    address impl,
    uint _nonce,
    address _owner
)
    view
    returns (address _address)
{
    bytes memory bytecode = type(ERC1967Proxy).creationCode;
    bytecode = abi.encodePacked(bytecode, abi.encode(impl, ""));
    bytes32 hashed = keccak256(
        abi.encodePacked(
            bytes1(0xff),
            address(factory),
            keccak256(abi.encodePacked(block.chainid, _nonce, _owner)),
            keccak256(bytecode)
        )
    );
    _address = address(uint160(uint256(hashed)));
}

function toX96(uint val) pure returns (uint valX96) {
    valX96 = (val << 96) / 1e18;
}

function toX32(uint val) pure returns (uint64 valX32) {
    valX32 = uint64((val << 32) / 1e18);
}

function toX16(uint val) pure returns (uint16 valX16) {
    valX16 = uint16((val << 16) / 1e18);
}

function toX16RatioTick(uint val) pure returns (uint16 valX16) {
    valX16 = uint16(val / 5);
}

contract AbstractFixedValueOracle is IPriceAdapter {
    uint p;

    constructor(uint _p) {
        p = _p;
    }

    function getPrice(uint feedId) external view override returns (uint price) {
        require(feedId == 10000123212, "invalid id");
        price = p;
    }
}

contract MultipoolUtils is Test {
    Multipool mp;
    Multipool mpImpl;
    MultipoolRouter router;
    DummyOracle oracle;

    MockERC20[] tokens;
    address[] users;

    address owner;
    uint ownerPk;

    address token0;
    address token1;
    address token2;
    address token3;
    address token4;

    address user0;
    address user1;
    address user2;
    address user3;

    using ECDSA for bytes32;

    function initMultipool() public {
        oracle = new DummyOracle(owner, 10000);

        mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(mpImpl), "");
        mp = Multipool(address(proxy));
        mp.initialize("Name", "SYMBOL", address(oracle), uint96(toX32(0.1e18)));
        router = new MultipoolRouter(address(0));
    }

    function assertEq(MpAsset memory a, MpAsset memory b) public pure {
        assertEq(a.quantity, b.quantity, "MpAsset quantity");
        assertEq(a.collectedCashbacks, b.collectedCashbacks, "MpAsset cashbacks");
        assertEq(a.targetShare, b.targetShare, "MpAsset share");
    }

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("Multipool owner");
        initMultipool();

        mp.transferOwnership(owner);
        oracle.transferOwnership(owner);

        token0 = address(new MockERC20("token0", "token0", 0));
        token1 = address(new MockERC20("token1", "token1", 0));
        token2 = address(new MockERC20("token2", "token2", 0));
        token3 = address(new MockERC20("token3", "token3", 0));
        token4 = address(new MockERC20("token4", "token4", 0));

        tokens.push(MockERC20(token0));
        tokens.push(MockERC20(token1));
        tokens.push(MockERC20(token2));
        tokens.push(MockERC20(token3));
        tokens.push(MockERC20(token4));

        user0 = makeAddr(string("user0"));
        user1 = makeAddr(string("user1"));
        user2 = makeAddr(string("user2"));
        user3 = makeAddr(string("user3"));

        users.push(user0);
        users.push(user1);
        users.push(user2);
        users.push(user3);

        for (uint u; u < users.length; u++) {
            for (uint t; t < tokens.length; t++) {
                tokens[t].mint(users[u], 100e18);
                vm.deal(users[u], 100e18);
            }
        }
    }

    function fixedValuePrice(uint128 val) public pure returns (bytes32 v) {
        v = setBytes(v, bytes32(uint(FeedType.FixedValue)), 0, 1);
        v = setBytes(v, bytes32(uint(val)), 1, 16);
    }

    function adapterPrice(address _addr, uint64 _feedId) public pure returns (bytes32 v) {
        v = setBytes(v, bytes32(uint(FeedType.Adapter)), 0, 1);
        v = setBytes(v, bytes32(uint(uint160(_addr))), 1, 20);
        v = setBytes(v, bytes32(uint(uint64(_feedId))), 21, 8);
    }

    function bootstrapMultipool(
        address[] memory assets,
        uint[] memory quoteValues,
        uint[] memory prices,
        uint16[] memory shares
    )
        public
    {
        vm.startPrank(owner);
        mp.setFeeParams(0, toX16RatioTick(1e5), 0, 0, address(0), 0);
        updatePrice(
            address(mp), address(mp), abi.encodePacked(FeedType.FixedValue, uint128(toX96(0.1e18)))
        );
        mp.updateStrategyManager(owner);

        mp.updateTargetShares(assets, shares);
        vm.deal(owner, 1e18);

        OraclePrice memory oraclePrice;
        ReceiverData memory rd;
        rd.receiverAddress = owner;
        rd.refundAddress = address(0);
        rd.refundEthToReceiver = true;

        for (uint i = 0; i < assets.length; i++) {
            uint val = (quoteValues[i] << 96) / prices[i];
            updatePrice(
                address(mp),
                address(tokens[i]),
                abi.encodePacked(FeedType.FixedValue, uint128(prices[i]))
            );
            tokens[i].mint(address(mp), val);
            tokens[i].mint(address(owner), 4000e18);
            mp.swap{value: 1e18}(oraclePrice, address(tokens[i]), address(mp), val, true, rd);
        }

        // insert adapter for token0 here
        address priceAdapter10 = address(new AbstractFixedValueOracle(prices[0]));
        updatePrice(
            address(mp),
            address(tokens[0]),
            abi.encodePacked(FeedType.Adapter, priceAdapter10, uint64(10000123212))
        );

        mp.setFeeParams(
            toX16RatioTick(0.0003e5),
            toX16RatioTick(0.15e5),
            toX16RatioTick(0.6e5),
            toX16RatioTick(0.01e5),
            owner,
            toX16RatioTick(0.1e5)
        );
        vm.stopPrank();
    }

    function genOraclePrice(
        uint pk,
        address contractAddress,
        uint ts,
        uint price
    )
        public
        view
        returns (OraclePrice memory op)
    {
        bytes memory data =
            abi.encodePacked(address(contractAddress), uint(ts), uint(price), uint(block.chainid));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, keccak256(data).toEthSignedMessageHash());
        op.timestamp = uint128(ts);
        op.sharePrice = uint128(price);
        op.contractAddress = address(contractAddress);
        op.signature = abi.encodePacked(r, s, v);
    }

    function swap(
        address sender,
        address assetIn,
        address assetOut,
        bool isExactInput,
        uint amount
    )
        public
    {
        OraclePrice memory oraclePrice;
        ReceiverData memory rd;
        rd.receiverAddress = sender;
        rd.refundAddress = address(0);
        rd.refundEthToReceiver = true;

        vm.prank(sender);
        mp.swap{value: 1e13}(oraclePrice, assetIn, assetOut, amount, isExactInput, rd);
    }

    function changePrice(address asset, uint price) public {
        vm.startPrank(owner);
        updatePrice(address(mp), asset, abi.encodePacked(FeedType.FixedValue, uint128(price)));
        vm.stopPrank();
    }

    function changeShare(address asset, uint16 share) public {
        vm.startPrank(owner);
        address[] memory addresses = new address[](1);
        addresses[0] = asset;
        uint16[] memory shares = new uint16[](1);
        shares[0] = share;
        mp.updateTargetShares(addresses, shares);
        vm.stopPrank();
    }

    function setCurveParams(uint16 dl, uint16 hf, uint16 bf, uint16 dbf) public {
        vm.startPrank(owner);
        OraclePrice memory s;
        address managementFeeRecepient = mp.getContext(s).managementFeeRecepient;
        uint16 managementFee = uint16(mp.getContext(s).managementBaseFee * 1e5 / (5 << 32));
        mp.setFeeParams(dl, hf, dbf, bf, managementFeeRecepient, managementFee);
        vm.stopPrank();
    }

    function jsonString(uint num) public pure returns (string memory str) {
        str = string.concat(vm.toString(num));
    }

    function snapMultipool(string memory path) public {
        if (!vm.envOr("CHECK_SNAPS", true)) {
            return;
        }
        vm.pauseGasMetering();
        string memory usersJson;
        string memory tokenJson;
        string memory mpJson;

        address[] memory userAddresses = new address[](users.length + 1);
        for (uint i; i < users.length; ++i) {
            userAddresses[i] = users[i];
        }
        userAddresses[users.length] = address(mp);

        for (uint i; i < userAddresses.length; ++i) {
            address user = userAddresses[i];
            uint ethBalance = address(user).balance;
            vm.serializeString("t", "ETH balance", jsonString(ethBalance));
            for (uint j; j < tokens.length; ++j) {
                vm.serializeString(
                    "t",
                    string.concat("token", vm.toString(j), " balance"),
                    jsonString(tokens[j].balanceOf(user))
                );
            }
            string memory userJson =
                vm.serializeString("t", "share balance", jsonString(mp.balanceOf(user)));

            if (user == address(mp)) {
                usersJson = vm.serializeString("users", "multipool", userJson);
            } else {
                usersJson =
                    vm.serializeString("users", string.concat("user", vm.toString(i)), userJson);
            }
        }

        for (uint i; i < tokens.length; ++i) {
            MpAsset memory a = mp.getAsset(address(tokens[i]));
            vm.serializeString("tk", "collectedCashbacks", jsonString(a.collectedCashbacks));
            vm.serializeString("tk", "targetShare", jsonString(a.targetShare));
            string memory token = vm.serializeString("tk", "quantity", jsonString(a.quantity));
            tokenJson = vm.serializeString("token", string.concat("token", vm.toString(i)), token);
        }

        vm.serializeString("multipool", "totalSupply", jsonString(mp.totalSupply()));

        OraclePrice memory fp;
        MpContext memory ctx = mp.getContext(fp);
        mpJson = vm.serializeString(
            "multipool", "deviationIncreaseFee", jsonString(ctx.deviationIncreaseFee)
        );
        mpJson = vm.serializeString("multipool", "deviationLimit", jsonString(ctx.deviationLimit));
        mpJson =
            vm.serializeString("multipool", "cashbackFeeShare", jsonString(ctx.feeToCashbackRatio));
        mpJson = vm.serializeString("multipool", "baseFee", jsonString(ctx.baseFee));
        mpJson = vm.serializeString(
            "multipool", "managementFeeRecepientAddress", vm.toString(ctx.managementFeeRecepient)
        );
        mpJson = vm.serializeString("multipool", "managementFee", jsonString(ctx.managementBaseFee));
        mpJson = vm.serializeString("multipool", "oracleAddress", vm.toString(ctx.oracleAddress));
        mpJson =
            vm.serializeString("multipool", "totalTargetShares", jsonString(ctx.totalTargetShares));

        string memory snapJson;
        vm.serializeString("snap", "users", usersJson);
        vm.serializeString("snap", "tokens", tokenJson);
        snapJson = vm.serializeString("snap", "multipool", mpJson);

        string memory oldJson;
        string memory fpath = string.concat("test/snapshots/", string.concat(path, ".json"));
        if (vm.exists(fpath)) oldJson = vm.readFile(fpath);

        string memory nfpath = string.concat("test/snapshots/", string.concat(path, ".new.json"));
        vm.writeJson(snapJson, nfpath);
        string memory newJson = vm.readFile(nfpath);

        vm.resumeGasMetering();
        if (keccak256(abi.encodePacked((oldJson))) != keccak256(abi.encodePacked((newJson)))) {
            revert(string.concat("Snapshots are not equal for ", path));
        }
        if (keccak256(abi.encodePacked((oldJson))) == keccak256(abi.encodePacked((newJson)))) {
            vm.removeFile(nfpath);
        }
    }
}

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256
    // deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    // computes the hash of a permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                _permit.owner,
                _permit.spender,
                _permit.value,
                _permit.nonce,
                _permit.deadline
            )
        );
    }

    // computes the hash of the fully encoded EIP-712 message for the domain, which can be used to
    // recover the signer
    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }
}

function updatePrice(address multipoolAddress, address asset, bytes memory data) {
    address[] memory priceAddresses = new address[](1);
    priceAddresses[0] = asset;

    bytes32 val;
    assembly {
        val := mload(add(data, 32))
    }

    bytes32[] memory priceData = new bytes32[](1);
    priceData[0] = val;

    Multipool(multipoolAddress).updatePrices(priceAddresses, priceData);
}

function vec(address[5] memory _s) pure returns (address[] memory s) {
    s = new address[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(address[4] memory _s) pure returns (address[] memory s) {
    s = new address[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(address[3] memory _s) pure returns (address[] memory s) {
    s = new address[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(address[2] memory _s) pure returns (address[] memory s) {
    s = new address[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(address[1] memory _s) pure returns (address[] memory s) {
    s = new address[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint16[5] memory _s) pure returns (uint16[] memory s) {
    s = new uint16[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint16[4] memory _s) pure returns (uint16[] memory s) {
    s = new uint16[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint16[3] memory _s) pure returns (uint16[] memory s) {
    s = new uint16[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint16[2] memory _s) pure returns (uint16[] memory s) {
    s = new uint16[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint16[1] memory _s) pure returns (uint16[] memory s) {
    s = new uint16[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint[5] memory _s) pure returns (uint[] memory s) {
    s = new uint[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint[4] memory _s) pure returns (uint[] memory s) {
    s = new uint[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint[3] memory _s) pure returns (uint[] memory s) {
    s = new uint[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint[2] memory _s) pure returns (uint[] memory s) {
    s = new uint[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}

function vec(uint[1] memory _s) pure returns (uint[] memory s) {
    s = new uint[](_s.length);
    for (uint i; i < _s.length; ++i) {
        s[i] = _s[i];
    }
}
