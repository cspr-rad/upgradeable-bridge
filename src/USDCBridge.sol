// SPDX-License-Identifier: Apache
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IMintBurnToken} from "./interfaces/IMintBurnToken.sol";
import {IMessageTransmitter} from "./interfaces/IMessageTransmitter.sol";

contract USDCBridge is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    IMintBurnToken public usdc;
    IMessageTransmitter public messageTransmitter;
    uint256 public totalValueLocked = 0;

    error FailedToDeposit(address depositor, uint256 amount);
    error FailedToWithdraw(address recipient, uint256 amount);

    event UnlockAndWithdraw(address indexed recipient, uint256 amount);
    event Deposit(
        address indexed depositor,
        uint256 amount,
        uint256 totalValueLocked
    );

    function initialize(
        address _usdcAddress,
        address _messageTransmitterAddress
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        usdc = IMintBurnToken(_usdcAddress);
        messageTransmitter = IMessageTransmitter(_messageTransmitterAddress);
    }

    function deposit(
        uint256 _amount,
        bytes32 _recipient
    ) public whenNotPaused returns (bool) {
        if (!usdc.transferFrom(msg.sender, address(this), _amount)) {
            revert FailedToDeposit(msg.sender, _amount);
        }
        totalValueLocked += _amount;
        messageTransmitter.sendMessageWithCaller(
            1,
            _recipient,
            bytes32("foo"),
            ""
        );
        emit Deposit(msg.sender, _amount, totalValueLocked);
        return true;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function burnLockedUSDC() external onlyOwner whenNotPaused {
        usdc.burn(totalValueLocked);
        totalValueLocked = 0;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override(UUPSUpgradeable) onlyOwner {}

    function _withdraw(uint256 _amount, address _recipient) internal {
        if (!usdc.transfer(_recipient, _amount)) {
            revert FailedToWithdraw(_recipient, _amount);
        }
        emit UnlockAndWithdraw(_recipient, _amount);
    }
}
