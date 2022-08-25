// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/LentMyc.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Myc} from "src/Myc.sol";
import {DummyMycBuyer} from "src/DummyMycBuyer.sol";

contract Claiming is Test {
    using FixedPointMathLib for uint256;
    LentMyc mycLend;
    Myc myc;
    DummyMycBuyer mycBuyer;
    address constant FORGE_DEPLOYER =
        0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;
    uint256 constant EIGHT_DAYS = 60 * 60 * 24 * 8;
    uint256 constant FOUR_DAYS = EIGHT_DAYS / 2;
    uint256 constant TWO_HOURS = 60 * 60 * 2;
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000_000 * 10**18;
    uint256 constant depositCap = INITIAL_MINT_AMOUNT;

    // So we can receive ETH rewards
    receive() external payable {}

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

        mycBuyer = new DummyMycBuyer(address(myc));
        // Set mycBuyer
        mycLend.setMycBuyer(address(mycBuyer));
        myc.approve(address(mycLend), myc.balanceOf(address(this)));
    }

    function testCanClaimWholeRewardAmountIfOnlyOneStaked(
        uint256 depositAmount,
        uint256 rewardAmount
    ) public {
        vm.assume(rewardAmount < depositCap);
        vm.assume(depositAmount < myc.balanceOf(address(this)));
        vm.assume(depositAmount > 0);
        mycLend.deposit(depositAmount, address(this));
        vm.warp(block.timestamp + EIGHT_DAYS);

        mycLend.newCycle{value: rewardAmount}(0, 0);

        uint256 preBalance = address(this).balance;
        assertEq(mycLend.getClaimableAmount(address(this)), 0);
        mycLend.claim();
        uint256 postBalance = address(this).balance;
        assertEq(postBalance, preBalance);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        preBalance = address(this).balance;
        assertApproxEqAbs(
            mycLend.getClaimableAmount(address(this)),
            rewardAmount * 2,
            mycLend.dust() + 1
        );
        mycLend.claim();
        postBalance = address(this).balance;
        assertApproxEqAbs(
            postBalance - preBalance,
            (rewardAmount * 2 - mycLend.dust()),
            mycLend.dust() + 1
        );
    }

    function testCanClaimNthRewardAmountIfNStaked(
        uint256 depositAmount,
        uint256 rewardAmount,
        uint256 participants
    ) public {
        vm.assume(rewardAmount < depositCap);
        vm.assume(depositAmount < myc.balanceOf(address(this)) / 3);
        vm.assume(depositAmount > 0);
        vm.assume(participants < depositAmount);
        // Limit to 200000000 otherwise takes too long
        vm.assume(participants < 200000000);

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));

            myc.transfer(user, depositAmount / participants);
            vm.prank(user);
            myc.approve(address(mycLend), depositAmount / participants);
            vm.prank(user);
            mycLend.deposit(depositAmount / participants, user);
        }

        vm.warp(block.timestamp + EIGHT_DAYS);

        mycLend.newCycle{value: rewardAmount}(0, 0);

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));
            uint256 preBalance = user.balance;
            assertEq(mycLend.getClaimableAmount(user), 0);
            mycLend.claim();
            uint256 postBalance = user.balance;
            assertEq(postBalance, preBalance);
        }

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        for (uint256 i = 0; i < participants; i++) {
            console.log("   ");
            address user = address(uint160(i + 10));
            // ADDRESS(THIS)
            uint256 preBalance = user.balance;
            assertApproxEqAbs(
                mycLend.getClaimableAmount(user),
                (rewardAmount * 2) / participants,
                mycLend.dust() + 1
            );
            console.log("user: %s", user);
            vm.prank(user);
            mycLend.claim();
            uint256 postBalance = user.balance;
            assertApproxEqAbs(
                postBalance - preBalance,
                (rewardAmount * 2) / participants,
                mycLend.dust() + 1
            );
        }
    }
}
