// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BurnMessage} from "../src/messages/BurnMessage.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MessageTransmitter} from "../src/MessageTransmitter.sol";
import {Message} from "../src/messages/Message.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {Test} from "forge-std/Test.sol";
import {USDCBridge} from "../src/USDCBridge.sol";

contract USDCBridgeTest is Test {
    MockUSDC public usdc;
    USDCBridge public usdcBridge;
    MessageTransmitter public messageTransmitter;
    uint256 constant INITIAL_SUPPLY = 200_000_000_000;
    uint32 constant MAX_MESSAGE_BODY_SIZE = 8192; // see: https://github.com/circlefin/evm-cctp-contracts/blob/377c9bd813fb86a42d900ae4003599d82aef635a/scripts/deploy.s.sol#L25

    function setUp() public {
        usdc = new MockUSDC(INITIAL_SUPPLY);
        messageTransmitter = new MessageTransmitter(
            0,
            address(0x01),
            MAX_MESSAGE_BODY_SIZE,
            2
        );
        address proxy = address(
            new ERC1967Proxy(
                address(new USDCBridge()),
                abi.encodeCall(
                    USDCBridge.initialize,
                    (address(usdc), address(messageTransmitter))
                )
            )
        );
        usdcBridge = USDCBridge(proxy);
        usdcBridge.setRemoteTokenMessenger(bytes32("foo"));
    }

    function testCantCallInitializeAgain() public {
        vm.expectRevert();
        usdcBridge.initialize(address(usdc), address(messageTransmitter));
    }

    function testDeposit() public {
        assertEq(
            usdc.balanceOf(address(usdcBridge)),
            0,
            "initial balance should be 0 before deposit"
        );
        assertEq(
            usdcBridge.totalValueLocked(),
            0,
            "total value locked should be 0 after deposit"
        );
        usdc.approve(address(usdcBridge), 1);
        usdcBridge.deposit(1, "foo");
        assertEq(
            usdc.balanceOf(address(usdcBridge)),
            1,
            "balance should be 1 after deposit"
        );
        assertEq(
            usdcBridge.totalValueLocked(),
            1,
            "total value locked should be 1 after deposit"
        );
    }

    function testCantDepositWhenPaused() public {
        usdcBridge.pause();
        usdc.approve(address(usdcBridge), 1);
        vm.expectRevert();
        usdcBridge.deposit(1, "foo");
    }

    function testBurnLockedUSEDC() public {
        usdc.approve(address(usdcBridge), 1);
        usdcBridge.deposit(1, "foo");
        assertEq(
            usdc.balanceOf(address(usdcBridge)),
            1,
            "balance should be 1 after deposit"
        );
        assertEq(
            usdcBridge.totalValueLocked(),
            1,
            "total value locked should be 1 after deposit"
        );
        usdcBridge.burnLockedUSDC();
        assertEq(
            usdc.balanceOf(address(usdcBridge)),
            0,
            "balance should be 0 after burn"
        );
        assertEq(
            usdcBridge.totalValueLocked(),
            0,
            "total value locked should be 0 after burn"
        );
    }

    function testHandleRecieveMessage() public {
        assertEq(
            usdc.balanceOf(address(0x01)),
            0,
            "initial balance should be 0"
        );
        testDeposit();
        bytes memory messageBody = BurnMessage._formatMessage(
            2,
            bytes32("foo"),
            Message.addressToBytes32(address(0x01)),
            1,
            bytes32("foo")
        );
        hoax(address(messageTransmitter));
        usdcBridge.handleReceiveMessage(0, bytes32("foo"), messageBody);
        assertEq(
            usdc.balanceOf(address(0x01)),
            1,
            "balance of 0x01 should be 1"
        );
    }
}
