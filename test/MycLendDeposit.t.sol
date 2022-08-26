// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/LentMyc.sol";
import {Myc} from "src/Myc.sol";

contract MycLendDeposit is Test {
    LentMyc mycLend;
    Myc myc;
    uint256 EIGHT_DAYS = 60 * 60 * 24 * 8;
    uint256 FOUR_DAYS = EIGHT_DAYS / 2;
    uint256 TWO_HOURS = 60 * 60 * 2;
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000_000 * 10**18;
    uint256 depositCap = INITIAL_MINT_AMOUNT;

    function setUp() public {
        vm.warp(EIGHT_DAYS);
        myc = new Myc("Mycelium", "MYC", 18);

        // Deploy a new lending contract with the cycle starting 4 days ago
        mycLend = new LentMyc(
            address(myc),
            address(this),
            18,
            EIGHT_DAYS,
            block.timestamp - FOUR_DAYS,
            TWO_HOURS,
            depositCap
        );
    }

    /**
     * @notice You don't get share in vault immediately.
     */
    function testDepositSetsCorrectVariables() public {
        uint256 depositAmount = 100;
        uint256 cycle = mycLend.cycle();
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(100, address(this));
        assertEq(mycLend.userPendingDeposits(address(this)), depositAmount);
        assertEq(mycLend.latestPendingDeposit(address(this)), cycle);
        assertEq(mycLend.userPendingRedeems(address(this)), 0);
        assertEq(mycLend.latestPendingRedeem(address(this)), 0);
    }

    /**
     * @notice You don't get share in vault immediately.
     */
    function testInitialDepositNoImmediateTokens() public {
        uint256 depositAmount = 100;
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));
        assertEq(mycLend.balanceOf(address(this)), 0);
    }

    /**
     * @notice After next cycle starts, you should get shares
     */
    function testInitialOneToOneRatio(uint256 depositAmount) public {
        vm.assume(depositAmount > 0);
        vm.assume(depositAmount < INITIAL_MINT_AMOUNT / 4);
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));

        // Cycle time ended, start new cycle
        vm.warp(block.timestamp + FOUR_DAYS);
        mycLend.newCycle(0, 0);

        // Balance not yet updated, but trueBalanceOf should reflect deposit
        assertEq(mycLend.balanceOf(address(this)), 0);
        assertEq(mycLend.trueBalanceOf(address(this)), depositAmount);

        // Update user and check balance
        mycLend.updateUser(address(this));
        assertEq(mycLend.balanceOf(address(this)), depositAmount);
    }

    /**
     * @notice After next cycle starts, you should get shares. If you deposit multiple times, you should get all of them.
     */
    function testInitialOneToOneRatioWithMultipleDepositsInSameCycle() public {
        uint256 depositAmount = 100;
        myc.approve(address(mycLend), depositAmount * 3);
        // Deposit 3 times
        mycLend.deposit(depositAmount, address(this));
        mycLend.deposit(depositAmount, address(this));
        mycLend.deposit(depositAmount, address(this));

        // Cycle time ended, start new cycle
        vm.warp(block.timestamp + FOUR_DAYS);
        mycLend.newCycle(0, 0);

        // Balance not yet updated, but trueBalanceOf should reflect deposit
        assertEq(mycLend.balanceOf(address(this)), 0);
        assertEq(mycLend.trueBalanceOf(address(this)), depositAmount * 3);

        // Update user and check balance
        mycLend.updateUser(address(this));
        assertEq(mycLend.balanceOf(address(this)), depositAmount * 3);
    }

    function testCannotDepositZero() public {
        uint256 depositAmount = 0;
        myc.approve(address(mycLend), depositAmount);
        vm.warp(block.timestamp + FOUR_DAYS);
        vm.expectRevert("assets == 0");
        mycLend.deposit(depositAmount, address(this));
    }

    /**
     * @notice When in the pre-cycle timelock, users' deposits should be locked.
     */
    function testCannotDepositInPreCycleTimelock() public {
        uint256 depositAmount = 100;
        myc.approve(address(mycLend), depositAmount);
        vm.warp(block.timestamp + FOUR_DAYS);
        vm.expectRevert("Deposit requests locked");
        mycLend.deposit(depositAmount, address(this));
    }

    function testCannotDepositMoreThanBalance() public {
        address user = address(123);
        myc.transfer(user, 10000);
        uint256 depositAmount = myc.balanceOf(user) + 1;
        vm.prank(user);
        myc.approve(address(mycLend), 10000000);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        vm.prank(user);
        mycLend.deposit(depositAmount, user);
    }

    /**
     * @notice After next cycle starts, you should get shares at 1:1 rate, even after tokens are taken
     */
    function testInitialOneToOneRatioAfterLosses() public {
        uint256 depositAmount = 100;
        uint256 lossAmount = 20;
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));

        // Cycle time ended, start new cycle
        vm.warp(block.timestamp + FOUR_DAYS);
        mycLend.newCycle(lossAmount, 10);

        // Balance not yet updated, but trueBalanceOf should reflect deposit
        assertEq(mycLend.balanceOf(address(this)), 0);
        assertEq(mycLend.trueBalanceOf(address(this)), depositAmount);

        // Update user and check balance
        mycLend.updateUser(address(this));
        assertEq(mycLend.balanceOf(address(this)), depositAmount);
    }

    function testDepositRatioAfterLosses() public {
        uint256 depositAmount = 100;
        uint256 lossAmount = 20;
        uint256 amountToWithdraw = 30;
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));

        // Cycle time ended, start new cycle. 0 rewards
        vm.warp(block.timestamp + FOUR_DAYS);
        mycLend.newCycle(0, 0);

        // New cycle with rewards. Ratio should now be 1:0.8
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(lossAmount, amountToWithdraw);

        // Balance not yet updated, but trueBalanceOf should reflect deposit
        assertEq(mycLend.balanceOf(address(this)), 0);
        // Still same amount of shares, but worth of those shares should go up
        assertEq(mycLend.trueBalanceOf(address(this)), depositAmount);
        // Because we are the only address to have entered, we are entitled to all the shares
        assertEq(
            mycLend.previewRedeem(mycLend.trueBalanceOf(address(this))),
            depositAmount - lossAmount
        );

        // Update user and check balance
        mycLend.updateUser(address(this));
        assertEq(mycLend.balanceOf(address(this)), depositAmount);
    }

    function testDepositRatioAfterMultipleCycles() public {
        uint256 depositAmount = 100;
        uint256 lossAmount = 20;
        uint256 rewardAmount = 30;
        uint256 amountToWithdraw = 30;
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));

        // Cycle time ended, start new cycle. 0 rewards
        vm.warp(block.timestamp + FOUR_DAYS);
        mycLend.newCycle(0, 0);

        // New cycle with rewards. Ratio should now be 1:0.8
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(lossAmount, amountToWithdraw);

        // New cycle with rewards. Ratio should now be 1:0.8
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, amountToWithdraw);

        // Balance not yet updated, but trueBalanceOf should reflect deposit
        assertEq(mycLend.balanceOf(address(this)), 0);
        // Still same amount of shares, but worth of those shares should go up
        assertEq(mycLend.trueBalanceOf(address(this)), depositAmount);
        // Because we are the only address to have entered, we are entitled to all the shares
        assertEq(
            mycLend.previewRedeem(mycLend.trueBalanceOf(address(this))),
            depositAmount - lossAmount
        );

        // Update user and check balance
        mycLend.updateUser(address(this));
        assertEq(mycLend.balanceOf(address(this)), depositAmount);
    }

    function testDepositRatioAfterMultipleCyclesMultipleParticipants() public {
        uint256 depositAmount = 100;
        uint256 lossAmount = 20;
        uint256 rewardAmount = 30;
        uint256 amountToWithdraw = 30;
        address user = address(123);
        myc.transfer(user, depositAmount);
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));
        vm.prank(user);
        myc.approve(address(mycLend), depositAmount);
        vm.prank(user);
        mycLend.deposit(depositAmount, user);

        // Cycle time ended, start new cycle. 0 rewards
        vm.warp(block.timestamp + FOUR_DAYS);
        mycLend.newCycle(0, 0);

        // New cycle with rewards. Ratio should now be 1:0.8
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(lossAmount, amountToWithdraw);

        // New cycle with rewards. Ratio should still be 1:0.8
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, amountToWithdraw);

        // Balance not yet updated, but trueBalanceOf should reflect deposit
        assertEq(mycLend.balanceOf(address(this)), 0);
        assertEq(mycLend.balanceOf(user), 0);
        // Still same amount of shares, but worth of those shares should go up
        assertEq(mycLend.trueBalanceOf(user), depositAmount);
        // Because there are two addresses that have entered, we are entitled to half the shares
        assertEq(
            mycLend.previewRedeem(mycLend.trueBalanceOf(address(this))),
            depositAmount - (lossAmount / 2)
        );

        assertEq(
            mycLend.previewRedeem(mycLend.trueBalanceOf(user)),
            depositAmount - (lossAmount / 2)
        );

        // Update user and check balance
        mycLend.updateUser(address(this));
        assertEq(mycLend.balanceOf(address(this)), depositAmount);
        mycLend.updateUser(user);
        assertEq(mycLend.balanceOf(user), depositAmount);
    }
}
