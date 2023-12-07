//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint _totalSupply) ERC20(name, symbol) {
        _mint(msg.sender, _totalSupply);
    }

    function mint(address _to, uint _amount) public {
        require(_amount > 0, "ERC20: mint amount must be greater than 0");
        _mint(_to, _amount);
    }
}

contract MockERC20WithDecimals is ERC20, Ownable {
    uint8 decimalsOverride;

    constructor(string memory name, string memory symbol, uint8 _decimals) ERC20(name, symbol) {
        decimalsOverride = _decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimalsOverride;
    }

    function mint(address _to, uint _amount) public {
        require(_amount > 0, "ERC20: mint amount must be greater than 0");
        _mint(_to, _amount);
    }
}
