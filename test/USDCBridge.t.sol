// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {USDCBridge} from "../src/USDCBridge.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract USDCBridgeTest is Test {
    MockUSDC public usdc;
    USDCBridge public usdcBridge;
    uint256 constant INITIAL_SUPPLY = 200_000_000_000;

    function setUp() public {
        usdc = new MockUSDC(INITIAL_SUPPLY);
        address proxy = address(
            new ERC1967Proxy(
                address(new USDCBridge()),
                abi.encodeCall(USDCBridge.initialize, address(usdc))
            )
        );
        usdcBridge = USDCBridge(proxy);
    }

    function testCantCallInitializeAgain() public {
        vm.expectRevert();
        usdcBridge.initialize(address(usdc));
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
        usdcBridge.deposit(1);
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
        usdcBridge.deposit(1);
    }

    function testBurnLockedUSEDC() public {
        usdc.approve(address(usdcBridge), 1);
        usdcBridge.deposit(1);
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

    //     function testHandleRecieveMessage() public {
    //         assertEq(
    //             usdCoin.balanceOf(address(0x01)),
    //             0,
    //             "initial balance should be 0"
    //         );
    //         testDeposit();
    //         bytes memory messageBody = BurnMessage._formatMessage(
    //             MESSAGE_BODY_VERSION,
    //             bytes32("foo"),
    //             Message.addressToBytes32(address(0x01)),
    //             1,
    //             bytes32("foo")
    //         );
    //         usdcBridge.handleReceiveMessage(0, bytes32("foo"), messageBody);
    //         assertEq(
    //             usdCoin.balanceOf(address(0x01)),
    //             1,
    //             "balance of 0x01 should be 1"
    //         );
    //     }
}
