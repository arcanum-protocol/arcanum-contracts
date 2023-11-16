pragma solidity >=0.8.19;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";
import {MockERC20} from "../../src/mocks/erc20.sol";
import {Multipool, MpContext, MpAsset} from "../../src/multipool/Multipool.sol";
import "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import {FeedInfo, FeedType} from "../../src/multipool/PriceMath.sol";

contract MultipoolCornerCases is Test {
    Multipool mp;
    MockERC20[] tokens;
    address[] users;
    uint tokenNum;
    uint userNum;

    function initMultipool() public {
        Multipool mpImpl = new Multipool();
        ERC1967Proxy proxy = new ERC1967Proxy(address(mpImpl), "");
        mp = Multipool(address(proxy));
        mp.initialize("Name", "SYMBOL", address(this), toX96(0.1e18));
    }

    function setUp() public {
        tokenNum = 5;
        userNum = 4;

        initMultipool();

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

    function toX96(uint val) public pure returns (uint valX96) {
        valX96 = (val << 96) / 1e18;
    }

    function bootstrapTokens(uint[5] memory quoteValues) private {
        mp.setCurveParams(1e18, 0, 0, 0);
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
            console.log("value ", i+1, " ", val);
            mp.updatePrice(address(tokens[i]), FeedType.FixedValue, abi.encode(p[i]));
            tokens[i].mint(address(mp), val);
            args[i] = Multipool.AssetArg ({
                addr: address(tokens[i]),
                amount: int(val)
            });
        }

        console.log("quote sum ", quoteSum);
        args[5] = Multipool.AssetArg ({
            addr: address(mp),
            amount: -int((quoteSum << 96) / toX96(0.1e18))
        });

        mp.swap(args, false, users[3]);
        mp.setCurveParams(0.15e18, 0.0003e18, 0.6e18, 0.01e18);
    }

    function test_Bootstrap() public {
        bootstrapTokens([uint(400e18), 300e18, 300e18, 300e18, 300e18]);
        for(uint i = 0; i < 5; i++) {
            MpAsset memory asset = mp.getAsset(address(tokens[i]));
            console.log("index: ", i+1);
            console.log("quantity: ", asset.quantity);
            console.log("share: ", asset.share);
        }
            MpAsset memory asset = mp.getAsset(address(mp));
            console.log("index: ", "multipool");
            console.log("quantity: ", asset.quantity);
            console.log("share: ", asset.share);
            console.log("balance: ", mp.balanceOf(users[3]));
    }
}
