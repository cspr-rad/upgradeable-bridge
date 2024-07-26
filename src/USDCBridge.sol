// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBurnable} from "./interfaces/IBurnable.sol";

contract USDCBridge is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    IERC20 public usdc;
    uint256 public totalValueLocked = 0;

    error FailedToDeposit(address depositor, uint256 amount);

    function initialize(address usdcAddress) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        usdc = IERC20(usdcAddress);
    }

    function deposit(uint256 amount) public whenNotPaused returns (bool) {
        if (!usdc.transferFrom(msg.sender, address(this), amount)) {
            revert FailedToDeposit(msg.sender, amount);
        }
        totalValueLocked += amount;
        return true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function burnLockedUSDC() external onlyOwner {
        IBurnable(address(usdc)).burn(totalValueLocked);
        totalValueLocked = 0;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override(UUPSUpgradeable) onlyOwner {}
}
