// SPDX-License-Identifier: Apache
pragma solidity ^0.8.13;

import {BurnMessage} from "./messages/BurnMessage.sol";
import {IMessageHandler} from "./interfaces/IMessageHandler.sol";
import {IMessageTransmitter} from "./interfaces/IMessageTransmitter.sol";
import {IMintBurnToken} from "./interfaces/IMintBurnToken.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Message} from "./messages/Message.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TypedMemView} from "memview-sol/TypedMemView.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract USDCBridge is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    IMessageHandler
{
    uint32 public constant BURN_MESSAGE_VERSION = 2;
    uint32 public constant CASPER_REMOTE_DOMAIN = 506; // See https://github.com/satoshilabs/slips/blob/master/slip-0044.md

    IMintBurnToken public usdc;
    IMessageTransmitter public messageTransmitter;
    uint256 public totalValueLocked = 0;
    bytes32 public remoteTokenMessenger = 0x00;

    error IncorrectBurnMessageVersion(
        uint32 expectedBurnMessageVersion,
        uint32 actualBurnMessageVersion
    );
    error CallerIsNotMessageTransmitter(
        address caller,
        address messageTransmitter
    );
    error FailedToDeposit(address depositor, uint256 amount);
    error FailedToWithdraw(address recipient, uint256 amount);
    error IncorrectRemoteDomain(
        uint256 expectedRemoteDomain,
        uint256 actualRemoteDomain
    );
    error IncorrectRemoteTokenMessengerSender(
        bytes32 remoteTokenMessenger,
        bytes32 sender
    );
    error RemoteTokenMessengerNotSet();

    event UnlockAndWithdraw(address indexed recipient, uint256 amount);
    event Deposit(
        address indexed depositor,
        uint256 amount,
        uint256 totalValueLocked
    );

    using TypedMemView for bytes;

    function initialize(
        address _usdcAddress,
        address _messageTransmitterAddress
    ) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(msg.sender);
        usdc = IMintBurnToken(_usdcAddress);
        messageTransmitter = IMessageTransmitter(_messageTransmitterAddress);
    }

    function deposit(
        uint256 _amount,
        bytes32 _recipient
    ) external whenNotPaused returns (bool) {
        if (!usdc.transferFrom(msg.sender, address(this), _amount)) {
            revert FailedToDeposit(msg.sender, _amount);
        }
        totalValueLocked += _amount;
        bytes memory message = BurnMessage._formatMessage(
            BURN_MESSAGE_VERSION,
            Message.addressToBytes32(address(usdc)),
            _recipient,
            _amount,
            // (bytes32(0) here indicates that any address can call receiveMessage()
            // on the destination domain, triggering mint to specified `mintRecipient`)
            // see: https://github.com/circlefin/evm-cctp-contracts/blob/377c9bd813fb86a42d900ae4003599d82aef635a/src/TokenMessenger.sol#L169-L185
            bytes32(0)
        );
        if (remoteTokenMessenger == 0x00) {
            revert RemoteTokenMessengerNotSet();
        }
        messageTransmitter.sendMessage(
            CASPER_REMOTE_DOMAIN,
            remoteTokenMessenger,
            message
        );
        emit Deposit(msg.sender, _amount, totalValueLocked);
        return true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function setRemoteTokenMessenger(
        bytes32 _destinationTokenMessenger
    ) external onlyOwner {
        remoteTokenMessenger = _destinationTokenMessenger;
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function handleReceiveMessage(
        uint32 _remoteDomain,
        bytes32 _sender,
        bytes calldata _messageBody
    ) external override(IMessageHandler) returns (bool) {
        if (msg.sender != address(messageTransmitter)) {
            revert CallerIsNotMessageTransmitter(
                msg.sender,
                address(messageTransmitter)
            );
        }
        if (CASPER_REMOTE_DOMAIN == _remoteDomain) {
            revert IncorrectRemoteDomain(0, _remoteDomain);
        }
        if (_sender != remoteTokenMessenger) {
            revert IncorrectRemoteTokenMessengerSender(
                remoteTokenMessenger,
                _sender
            );
        }
        bytes29 message = _messageBody.ref(0);
        BurnMessage._validateBurnMessageFormat(message);
        uint32 burnMessageVersion = BurnMessage._getVersion(message);
        if (BURN_MESSAGE_VERSION != burnMessageVersion) {
            revert IncorrectBurnMessageVersion(
                BURN_MESSAGE_VERSION,
                burnMessageVersion
            );
        }
        bytes32 recipient = BurnMessage._getMintRecipient(message);
        uint256 amount = BurnMessage._getAmount(message);
        _withdraw(amount, Message.bytes32ToAddress(recipient));

        return true;
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
