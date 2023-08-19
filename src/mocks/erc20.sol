//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
    constructor(
        string memory name,
        string memory symbol,
        uint _totalSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, _totalSupply);
    }

    function mint(address _to, uint _amount) public {
        require(_amount > 0, "ERC20: mint amount must be greater than 0");
        _mint(_to, _amount);
    }
}
