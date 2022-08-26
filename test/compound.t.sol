// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/LentMyc.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Myc} from "src/Myc.sol";
import {DummyMycBuyer} from "src/DummyMycBuyer.sol";

contract Compound is Test {
    using FixedPointMathLib for uint256;
    LentMyc mycLend;
    Myc myc;
    DummyMycBuyer mycBuyer;
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
        myc.transfer(address(mycBuyer), 100 * 10**18);
    }

    function testCompoundAboveCap() public {
        uint256 depositAmount = 100 * 10**18;
        uint256 rewardAmount = 1 * 10**15;
        mycLend.setDepositCap(depositAmount);
        myc.approve(address(mycLend), type(uint256).max);
        mycLend.deposit(depositAmount, address(this));

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        vm.expectRevert("Deposit cap exceeded");
        mycLend.compound(address(this), "");
    }
}
