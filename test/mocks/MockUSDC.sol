// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IBurnable} from "../../src/interfaces/IBurnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20, IBurnable {
    constructor(uint256 initialSupply) ERC20("USDCoin", "USDC") {
        _mint(msg.sender, initialSupply);
    }

    function burn(uint256 amount) external override(IBurnable) {
        _burn(msg.sender, amount);
    }
}
