// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../src/multipool/Multipool.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedInfo, FeedType} from "../src/lib/Price.sol";

import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "openzeppelin/utils/cryptography/MessageHashUtils.sol";

function toX96(uint val) pure returns (uint valX96) {
    valX96 = (val << 96) / 1e18;
}

function toX32(uint val) pure returns (uint64 valX32) {
    valX32 = uint64((val << 32) / 1e18);
}

contract MultipoolUtils is Test {
    Multipool mp;
    MockERC20[] tokens;
    address[] users;
    uint tokenNum;
    uint userNum;
    address owner;
    uint ownerPk;

    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    function initMultipool() public {
        Multipool mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(mpImpl), "");
        mp = Multipool(address(proxy));
        mp.initialize("Name", "SYMBOL", address(this), toX96(0.1e18));
    }

    function assertEq(MpAsset memory a, MpAsset memory b) public {
        assertEq(a.quantity, b.quantity, "MpAsset quantity");
        assertEq(a.collectedCashbacks, b.collectedCashbacks, "MpAsset cashbacks");
        assertEq(a.share, b.share, "MpAsset share");
    }

    function setUp() public {
        tokenNum = 5;
        userNum = 4;

        initMultipool();

        (owner, ownerPk) = makeAddrAndKey("Multipool owner");
        mp.transferOwnership(owner);

        for (uint i; i < tokenNum; i++) {
            tokens.push(new MockERC20('token', 'token', 0));
        }
        for (uint i; i < userNum; i++) {
            users.push(makeAddr(string(abi.encode(i))));
        }
        for (uint u; u < userNum; u++) {
            for (uint t; t < tokenNum; t++) {
                tokens[t].mint(users[u], 10000000000e18);
            }
        }
    }

    function bootstrapTokens(uint[5] memory quoteValues, address to) public {
        vm.startPrank(owner);
        mp.setCurveParams(toX32(1e18), 0, 0, 0);
        mp.updatePrice(address(mp), FeedType.FixedValue, abi.encode(toX96(0.1e18)));

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

        Multipool.AssetArg[] memory args = new Multipool.AssetArg[](6);

        uint quoteSum;

        for (uint i = 0; i < t.length; i++) {
            quoteSum += quoteValues[i];
            uint val = (quoteValues[i] << 96) / p[i];
            mp.updatePrice(address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
            tokens[i].mint(address(mp), val);
            args[i] = Multipool.AssetArg({addr: address(tokens[i]), amount: int(val)});
        }

        args[5] = Multipool.AssetArg({addr: address(mp), amount: -int((quoteSum << 96) / toX96(0.1e18))});

        Multipool.FPSharePriceArg memory fp;
        mp.swap(fp, args, false, to, true, address(0));
        mp.setCurveParams(toX32(0.15e18), toX32(0.0003e18), toX32(0.6e18), toX32(0.01e18));
        vm.stopPrank();
    }

    struct SharePriceParams {
        bool send;
        uint128 value;
        uint128 ts;
    }

    function swap(Multipool.AssetArg[] memory assets, uint ethValue, address to, SharePriceParams memory sp) public {
        Multipool.FPSharePriceArg memory fp;
        if (sp.send) {
            fp.thisAddress = owner;
            fp.timestamp = sp.ts;
            fp.value = sp.value;
            bytes32 message = keccak256(abi.encodePacked(owner, sp.ts, sp.value)).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, message);
            bytes memory signature = abi.encodePacked(r, s, v);
            fp.signature = signature;
        }
        mp.swap{value: ethValue}(fp, assets, false, to, true, address(0));
    }

    function checkSwap(
        Multipool.AssetArg[] memory assets, 
        bool isSleepageReverse,
        SharePriceParams memory sp
    ) public view returns (int fee, int[] memory amounts) {
        Multipool.FPSharePriceArg memory fp;
        if (sp.send) {
            fp.thisAddress = owner;
            fp.timestamp = sp.ts;
            fp.value = sp.value;
            bytes32 message = keccak256(abi.encodePacked(owner, sp.ts, sp.value)).toEthSignedMessageHash();
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, message);
            bytes memory signature = abi.encodePacked(r, s, v);
            fp.signature = signature;
        }
        (fee, amounts) = mp.checkSwap(fp, assets, isSleepageReverse);
    }

    function changePrice(address asset, uint price) public {
        vm.startPrank(owner);
        mp.updatePrice(asset, FeedType.FixedValue, abi.encode(price));
        vm.stopPrank();
    }

    function setCurveParams(uint64 dl, uint64 hf, uint64 bf, uint64 dbf) public {
        vm.startPrank(owner);
        mp.setCurveParams(dl, hf, dbf, bf);
        vm.stopPrank();
    }

    struct TokenBalance {
        uint balance;
        address token;
    }

    struct User {
        address addr;
        uint ethBalance;
        TokenBalance[] balances;
    }

    struct Asset {
        address addr;
        uint collectedCashbacks;
        uint share;
        uint quantity;
    }

    struct MpData {
        uint totalSupply;
        uint totalCashback;
        uint totalCollectedFees;
        uint totalShares;
    }

    struct Snapshot {
        User[] users;
        Asset[] assets;
        MpData multipool;
    }

    function jsonString(uint num) public pure returns (string memory str) {
        str = string.concat("\"", vm.toString(num), "\"");
    }

    function snapMultipool(string memory path) public {
        User[] memory usrs = new User[](users.length+1);

        string memory usersJson;
        string memory tokenJson;
        string memory mpJson;

        for (uint i; i < users.length; ++i) {
            usrs[i].addr = users[i];
            usrs[i].ethBalance = address(users[i]).balance;
            vm.serializeString("t", "ethBalance", jsonString(usrs[i].ethBalance));
            TokenBalance[] memory balances = new TokenBalance[](tokens.length+1);
            for (uint j; j < tokens.length; ++j) {
                balances[j].token = address(tokens[j]);
                balances[j].balance = tokens[j].balanceOf(users[i]);
                vm.serializeString("t", string.concat("tokenBalance", vm.toString(i)), jsonString(balances[j].balance));
            }
            balances[tokens.length].token = address(mp);
            balances[tokens.length].balance = mp.balanceOf(users[i]);
            string memory userJson =
                vm.serializeString("t", "tokenBalanceMultipool", jsonString(balances[tokens.length].balance));

            usrs[i].balances = balances;
            usersJson = vm.serializeString("users", string.concat("user", vm.toString(i)), userJson);
        }

        Asset[] memory assets = new Asset[](tokens.length);
        for (uint i; i < tokens.length; ++i) {
            assets[i].addr = address(tokens[i]);
            MpAsset memory a = mp.getAsset(address(tokens[i]));
            assets[i].collectedCashbacks = a.collectedCashbacks;
            vm.serializeString("tk", "cashbacks", jsonString(assets[i].collectedCashbacks));
            assets[i].share = a.share;
            vm.serializeString("tk", "share", jsonString(assets[i].share));
            assets[i].quantity = a.quantity;
            string memory token = vm.serializeString("tk", "quantity", jsonString(assets[i].quantity));
            tokenJson = vm.serializeString("token", string.concat("token", vm.toString(i)), token);
        }

        MpData memory data;
        data.totalSupply = mp.totalSupply();
        vm.serializeString("multipool", "totalSupply", jsonString(data.totalSupply));
        data.totalCashback = mp.totalCollectedCashbacks();
        vm.serializeString("multipool", "totalCashback", jsonString(data.totalCashback));
        data.totalCollectedFees = mp.collectedFees();
        vm.serializeString("multipool", "totalFees", jsonString(data.totalCollectedFees));
        data.totalShares = mp.totalTargetShares();
        mpJson = vm.serializeString("multipool", "totalShares", jsonString(data.totalShares));

        string memory snapJson;
        vm.serializeString("snap", "users", usersJson);
        vm.serializeString("snap", "tokens", tokenJson);
        snapJson = vm.serializeString("snap", "multipool", mpJson);

        Snapshot memory snap;
        snap.assets = assets;
        snap.users = usrs;
        snap.multipool = data;

        string memory oldJson;
        string memory fpath = string.concat("test/snapshots/", string.concat(path, ".json"));
        if (vm.exists(fpath)) oldJson = vm.readFile(fpath);

        string memory nfpath = string.concat("test/snapshots/", string.concat(path, ".new.json"));
        vm.writeJson(snapJson, nfpath);
        string memory newJson = vm.readFile(nfpath);

        if (
            keccak256(abi.encodePacked((oldJson))) != keccak256(abi.encodePacked((newJson)))
                && vm.envBool("CHECK_SNAPS")
        ) {
            revert(string.concat("Snapshots are not equal for ", path));
        } else {
            vm.removeFile(nfpath);
        }
    }

    function dynamic(Multipool.AssetArg[1] memory assets) public pure returns (Multipool.AssetArg[] memory dynarray) {
        dynarray = new Multipool.AssetArg[](assets.length);
        for (uint i; i < assets.length; ++i) {
            dynarray[i] = assets[i];
        }
    }

    function dynamic(Multipool.AssetArg[2] memory assets) public pure returns (Multipool.AssetArg[] memory dynarray) {
        dynarray = new Multipool.AssetArg[](assets.length);
        for (uint i; i < assets.length; ++i) {
            dynarray[i] = assets[i];
        }
    }

    function dynamic(Multipool.AssetArg[3] memory assets) public pure returns (Multipool.AssetArg[] memory dynarray) {
        dynarray = new Multipool.AssetArg[](assets.length);
        for (uint i; i < assets.length; ++i) {
            dynarray[i] = assets[i];
        }
    }

    function dynamic(Multipool.AssetArg[4] memory assets) public pure returns (Multipool.AssetArg[] memory dynarray) {
        dynarray = new Multipool.AssetArg[](assets.length);
        for (uint i; i < assets.length; ++i) {
            dynarray[i] = assets[i];
        }
    }

    function dynamic(Multipool.AssetArg[5] memory assets) public pure returns (Multipool.AssetArg[] memory dynarray) {
        dynarray = new Multipool.AssetArg[](assets.length);
        for (uint i; i < assets.length; ++i) {
            dynarray[i] = assets[i];
        }
    }

    function dynamic(Multipool.AssetArg[6] memory assets) public pure returns (Multipool.AssetArg[] memory dynarray) {
        dynarray = new Multipool.AssetArg[](assets.length);
        for (uint i; i < assets.length; ++i) {
            dynarray[i] = assets[i];
        }
    }
}
