// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MockERC20} from "../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../src/multipool/Multipool.sol";
import {MultipoolRouter} from "../src/multipool/MultipoolRouter.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedInfo, FeedType} from "../src/lib/Price.sol";
import {ForcePushArgs, AssetArgs} from "../src/types/SwapArgs.sol";
import {IPriceAdapter} from "../src/interfaces/IPriceAdapter.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";

function toX96(uint val) pure returns (uint valX96) {
    valX96 = (val << 96) / 1e18;
}

function toX32(uint val) pure returns (uint64 valX32) {
    valX32 = uint64((val << 32) / 1e18);
}

contract AbstractFixedValueOracle is IPriceAdapter {
    uint p;

    constructor(uint _p) {
        p = _p;
    }

    function getPrice(uint feedId) external view override returns (uint price) {
        require(feedId == 10000000000000000123212, "invalid id");
        price = p;
    }
}

contract MultipoolUtils is Test {
    Multipool mp;
    MultipoolRouter router;
    MockERC20[] tokens;
    address[] users;
    uint tokenNum;
    uint userNum;
    address owner;
    uint ownerPk;
    address implementation;

    using ECDSA for bytes32;

    function initMultipool() public {
        Multipool mpImpl = new Multipool();
        implementation = address(mpImpl);
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(mpImpl),
            abi.encodeWithSignature(
                "initialize(string,string,uint128)", "Name", "SYMBOL", uint128(toX96(0.1e18))
            )
        );
        mp = Multipool(address(proxy));
        //mp.initialize("Name", "SYMBOL", uint128(toX96(0.1e18)));
    }

    function assertEq(MpAsset memory a, MpAsset memory b) public {
        assertEq(a.quantity, b.quantity, "MpAsset quantity");
        assertEq(a.collectedCashbacks, b.collectedCashbacks, "MpAsset cashbacks");
        assertEq(a.targetShare, b.targetShare, "MpAsset share");
    }

    function setUp() public {
        tokenNum = 5;
        userNum = 4;

        initMultipool();

        router = new MultipoolRouter();

        (owner, ownerPk) = makeAddrAndKey("Multipool owner");
        mp.transferOwnership(owner);

        for (uint i; i < tokenNum; i++) {
            tokens.push(new MockERC20("token", "token", 0));
        }
        for (uint i; i < userNum; i++) {
            users.push(makeAddr(string(abi.encode(i))));
        }
        for (uint u; u < userNum; u++) {
            for (uint t; t < tokenNum; t++) {
                tokens[t].mint(users[u], 100e18);
            }
        }
    }

    function bootstrapTokens(uint[5] memory quoteValues, address to) public {
        vm.startPrank(owner);
        mp.setFeeParams(toX32(1e18), 0, 0, 0, 0, address(0));
        updatePrice(address(mp), address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));
        mp.setAuthorityRights(owner, true, true);

        uint[] memory p = new uint[](5);
        p[0] = toX96(10e18);
        p[1] = toX96(20e18);
        p[2] = toX96(5e18);
        p[3] = toX96(2.5e18);
        p[4] = toX96(10e18);

        address[] memory t = new address[](5);
        t[0] = address(tokens[0]);
        t[1] = address(tokens[1]);
        t[2] = address(tokens[2]);
        t[3] = address(tokens[3]);
        t[4] = address(tokens[4]);

        uint[] memory s = new uint[](5);
        s[0] = 10e18;
        s[1] = 10e18;
        s[2] = 10e18;
        s[3] = 10e18;
        s[4] = 10e18;

        mp.updateTargetShares(t, s);

        AssetArgs[] memory args = new AssetArgs[](6);

        uint quoteSum;

        for (uint i = 0; i < t.length; i++) {
            quoteSum += quoteValues[i];
            uint val = (quoteValues[i] << 96) / p[i];
            updatePrice(address(mp), address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
            if (val > 0) {
                tokens[i].mint(address(mp), val);
            }
            args[i] = AssetArgs({assetAddress: address(tokens[i]), amount: int(val)});
        }

        // insert adapter for token 1 here
        address priceAdapter10 = address(new AbstractFixedValueOracle(p[0]));

        address[] memory priceAdapterAddresses = new address[](2);
        priceAdapterAddresses[0] = address(tokens[0]);
        priceAdapterAddresses[1] = address(tokens[1]);
        FeedType[] memory priceAdapterType = new FeedType[](2);
        priceAdapterType[0] = FeedType.Adapter;
        priceAdapterType[1] = FeedType.FixedValue;
        bytes[] memory priceAdapterBytes = new bytes[](2);
        priceAdapterBytes[0] = abi.encode(priceAdapter10, uint(10000000000000000123212));
        priceAdapterBytes[1] = abi.encode(p[1]);
        mp.updatePrices(priceAdapterAddresses, priceAdapterType, priceAdapterBytes);

        args[5] =
            AssetArgs({assetAddress: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))});

        args = sort(args);

        ForcePushArgs memory fp;
        mp.swap(fp, args, true, to, false, users[3]);
        mp.setFeeParams(
            toX32(0.15e18), toX32(0.0003e18), toX32(0.6e18), toX32(0.01e18), toX32(0.1e18), users[2]
        );
        vm.stopPrank();
    }

    struct SharePriceParams {
        bool send;
        uint128 value;
        uint128 ts;
    }

    function swap(
        AssetArgs[] memory assets,
        uint ethValue,
        address to,
        SharePriceParams memory sp
    )
        public
    {
        swapExt(assets, ethValue, to, sp, users[3], true, false, abi.encode(0));
    }

    function swapExt(
        AssetArgs[] memory assets,
        uint ethValue,
        address to,
        SharePriceParams memory sp,
        address refundTo,
        bool isExactInput,
        bool refundEthToReceiver,
        bytes memory error
    )
        public
    {
        ForcePushArgs memory fp;
        if (sp.send) {
            fp.contractAddress = address(mp);
            fp.timestamp = sp.ts;
            fp.sharePrice = sp.value;
            bytes32 message = keccak256(
                abi.encodePacked(fp.contractAddress, uint(sp.ts), uint(sp.value), block.chainid)
            ).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, message);
            bytes memory signature = abi.encodePacked(r, s, v);
            fp.signatures = new bytes[](1);
            fp.signatures[0] = signature;
        }
        if (keccak256(error) != keccak256(abi.encode(0))) {
            vm.expectRevert(error);
        }
        mp.swap{value: ethValue}(fp, assets, isExactInput, to, refundEthToReceiver, refundTo);
    }

    function checkSwap(
        AssetArgs[] memory assets,
        bool isExactInput,
        SharePriceParams memory sp
    )
        public
        view
        returns (int fee, int[] memory amounts)
    {
        ForcePushArgs memory fp;
        if (sp.send) {
            fp.contractAddress = owner;
            fp.timestamp = sp.ts;
            fp.sharePrice = sp.value;
            bytes32 message =
                keccak256(abi.encodePacked(owner, sp.ts, sp.value)).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, message);
            bytes memory signature = abi.encodePacked(r, s, v);
            fp.signatures = new bytes[](1);
            fp.signatures[0] = signature;
        }
        (fee, amounts) = mp.checkSwap(fp, assets, isExactInput);
    }

    function changePrice(address asset, uint price) public {
        vm.startPrank(owner);
        updatePrice(address(mp), asset, FeedType.FixedValue, abi.encode(price));
        vm.stopPrank();
    }

    function changeShare(address asset, uint share) public {
        vm.startPrank(owner);
        address[] memory addresses = new address[](1);
        addresses[0] = asset;
        uint[] memory shares = new uint[](1);
        shares[0] = share;
        mp.updateTargetShares(addresses, shares);
        vm.stopPrank();
    }

    function setCurveParams(uint64 dl, uint64 hf, uint64 bf, uint64 dbf) public {
        vm.startPrank(owner);
        (,,,, uint64 developerFee, address developerAddress) = mp.getFeeParams();
        mp.setFeeParams(dl, hf, dbf, bf, developerFee, developerAddress);
        vm.stopPrank();
    }

    function jsonString(uint num) public pure returns (string memory str) {
        str = string.concat("\"", vm.toString(num), "\"");
    }

    function snapMultipool(string memory path) public {
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
            vm.serializeString("t", "ethBalance", jsonString(ethBalance));
            for (uint j; j < tokens.length; ++j) {
                vm.serializeString(
                    "t",
                    string.concat("tokenBalance", vm.toString(j)),
                    jsonString(tokens[j].balanceOf(user))
                );
            }
            string memory userJson =
                vm.serializeString("t", "tokenBalanceMultipool", jsonString(mp.balanceOf(user)));

            if (user == address(mp)) {
                usersJson = vm.serializeString("users", "multipool", userJson);
            } else {
                usersJson =
                    vm.serializeString("users", string.concat("user", vm.toString(i)), userJson);
            }
        }

        for (uint i; i < tokens.length; ++i) {
            MpAsset memory a = mp.getAsset(address(tokens[i]));
            vm.serializeString("tk", "cashbacks", jsonString(a.collectedCashbacks));
            vm.serializeString("tk", "share", jsonString(a.targetShare));
            string memory token = vm.serializeString("tk", "quantity", jsonString(a.quantity));
            tokenJson = vm.serializeString("token", string.concat("token", vm.toString(i)), token);
        }

        vm.serializeString("multipool", "totalSupply", jsonString(mp.totalSupply()));
        vm.serializeString("multipool", "totalCashback", jsonString(mp.totalCollectedCashbacks()));
        vm.serializeString("multipool", "totalFees", jsonString(mp.collectedFees()));
        vm.serializeString("multipool", "totalDevFees", jsonString(mp.collectedDeveloperFees()));
        mpJson = vm.serializeString("multipool", "totalShares", jsonString(mp.totalTargetShares()));

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

        if (
            keccak256(abi.encodePacked((oldJson))) != keccak256(abi.encodePacked((newJson)))
                && vm.envOr("CHECK_SNAPS", true)
        ) {
            revert(string.concat("Snapshots are not equal for ", path));
        }
        if (keccak256(abi.encodePacked((oldJson))) == keccak256(abi.encodePacked((newJson)))) {
            vm.removeFile(nfpath);
        }
    }
}

function updatePrice(address multipoolAddress, address asset, FeedType kind, bytes memory data) {
    address[] memory priceAddresses = new address[](1);
    priceAddresses[0] = asset;

    FeedType[] memory priceTypes = new FeedType[](1);
    priceTypes[0] = kind;

    bytes[] memory priceDatas = new bytes[](1);
    priceDatas[0] = data;

    Multipool(multipoolAddress).updatePrices(priceAddresses, priceTypes, priceDatas);
}

function sort(AssetArgs[] memory arr) pure returns (AssetArgs[] memory a) {
    uint i;
    AssetArgs memory key;
    uint j;

    for (i = 1; i < arr.length; i++) {
        key = arr[i];

        for (j = i; j > 0 && arr[j - 1].assetAddress > key.assetAddress; j--) {
            arr[j] = arr[j - 1];
        }

        arr[j] = key;
    }
    a = arr;
}

function dynamic(AssetArgs[1] memory assets) pure returns (AssetArgs[] memory dynarray) {
    dynarray = new AssetArgs[](assets.length);
    for (uint i; i < assets.length; ++i) {
        dynarray[i] = assets[i];
    }
}

function dynamic(AssetArgs[2] memory assets) pure returns (AssetArgs[] memory dynarray) {
    dynarray = new AssetArgs[](assets.length);
    for (uint i; i < assets.length; ++i) {
        dynarray[i] = assets[i];
    }
}

function dynamic(AssetArgs[3] memory assets) pure returns (AssetArgs[] memory dynarray) {
    dynarray = new AssetArgs[](assets.length);
    for (uint i; i < assets.length; ++i) {
        dynarray[i] = assets[i];
    }
}

function dynamic(AssetArgs[4] memory assets) pure returns (AssetArgs[] memory dynarray) {
    dynarray = new AssetArgs[](assets.length);
    for (uint i; i < assets.length; ++i) {
        dynarray[i] = assets[i];
    }
}

function dynamic(AssetArgs[5] memory assets) pure returns (AssetArgs[] memory dynarray) {
    dynarray = new AssetArgs[](assets.length);
    for (uint i; i < assets.length; ++i) {
        dynarray[i] = assets[i];
    }
}

function dynamic(AssetArgs[6] memory assets) pure returns (AssetArgs[] memory dynarray) {
    dynarray = new AssetArgs[](assets.length);
    for (uint i; i < assets.length; ++i) {
        dynarray[i] = assets[i];
    }
}
