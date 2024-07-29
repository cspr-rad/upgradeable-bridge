// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IMintBurnToken} from "../../src/interfaces/IMintBurnToken.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20, IMintBurnToken {
    constructor(uint256 _initialSupply) ERC20("USDCoin", "USDC") {
        _mint(msg.sender, _initialSupply);
    }

    function burn(uint256 _amount) external override(IMintBurnToken) {
        _burn(msg.sender, _amount);
    }

    function mint(
        address,
        uint256
    ) external pure override(IMintBurnToken) returns (bool) {
        revert("Unimplemented");
    }
}
