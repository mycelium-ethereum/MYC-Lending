// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/V1/LentMyc.sol";
import {Myc} from "src/token/Myc.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Redeem is Test {
    LentMyc mycLend;
    Myc myc;
    LentMyc impl;
    uint256 EIGHT_DAYS = 60 * 60 * 24 * 8;
    uint256 FOUR_DAYS = EIGHT_DAYS / 2;
    uint256 TWO_HOURS = 60 * 60 * 2;
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000_000 * 10**18;
    uint256 depositCap = INITIAL_MINT_AMOUNT;
    address constant admin = address(123);

    function setUp() public {
        vm.warp(EIGHT_DAYS);
        myc = new Myc("Mycelium", "MYC", 18);

        // Deploy a new lending contract with the cycle starting 4 days ago
        impl = new LentMyc();
        impl.initialize(
            address(myc),
            address(this),
            // 18,
            EIGHT_DAYS,
            block.timestamp - FOUR_DAYS,
            TWO_HOURS,
            depositCap,
            admin
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), "");
        // cast proxy to LentMyc
        mycLend = LentMyc(address(proxy));
        mycLend.initialize(
            address(myc),
            address(this),
            // 18,
            EIGHT_DAYS,
            block.timestamp - FOUR_DAYS,
            TWO_HOURS,
            depositCap,
            admin
        );
    }

    function testRedeemAfterManyDeposits() public {
        uint256 depositAmount = 100;
        uint256 rewardAmount = 10;
        address user = address(123);
        myc.approve(address(mycLend), type(uint256).max);
        mycLend.deposit(100, address(this));

        myc.transfer(user, depositAmount * 10000);
        vm.prank(user);
        myc.approve(address(mycLend), type(uint256).max);
        vm.prank(user);
        mycLend.deposit(depositAmount, user);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);
        assertEq(mycLend.totalAssets(), 100 + depositAmount);
        // mycLend.redeem(depositAmount, address(this), address(this));
        vm.prank(user);
        mycLend.deposit(depositAmount, user);
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        assertEq(mycLend.totalAssets(), 100 + depositAmount * 2);
        mycLend.deposit(depositAmount, address(this));
        vm.prank(user);
        mycLend.deposit(depositAmount, user);
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        assertEq(mycLend.totalAssets(), 100 + depositAmount * 4);
        mycLend.deposit(depositAmount, address(this));
        vm.prank(user);
        mycLend.deposit(depositAmount, user);
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        assertEq(mycLend.totalAssets(), 100 + depositAmount * 6);
        mycLend.deposit(depositAmount, address(this));
        vm.prank(user);
        mycLend.deposit(depositAmount, user);
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        assertEq(mycLend.totalAssets(), 100 + depositAmount * 8);
        mycLend.deposit(depositAmount, address(this));
        vm.prank(user);
        mycLend.deposit(depositAmount, user);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        assertEq(mycLend.totalAssets(), 100 + depositAmount * 10);

        uint256 bal = mycLend.trueBalanceOf(user);
        vm.prank(user);
        mycLend.redeem(bal, user, user);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);
    }
}
