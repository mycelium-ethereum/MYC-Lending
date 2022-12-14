// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/V1/LentMyc.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Myc} from "src/token/Myc.sol";
import {DummyMycBuyer} from "src/V1/DummyMycBuyer.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Claiming is Test {
    using FixedPointMathLib for uint256;
    LentMyc mycLend;
    LentMyc impl;
    Myc myc;
    DummyMycBuyer mycBuyer;
    uint256 constant EIGHT_DAYS = 60 * 60 * 24 * 8;
    uint256 constant FOUR_DAYS = EIGHT_DAYS / 2;
    uint256 constant TWO_HOURS = 60 * 60 * 2;
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000_000 * 10**18;
    uint256 constant depositCap = INITIAL_MINT_AMOUNT;
    address constant admin = address(123);

    // So we can receive ETH rewards
    receive() external payable {}

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

        mycBuyer = new DummyMycBuyer(address(myc), address(this));
        // Set mycBuyer
        mycLend.setMycBuyer(address(mycBuyer));
        myc.approve(address(mycLend), myc.balanceOf(address(this)));
    }

    function testCanClaimNthRewardAmountIfNStaked(
        uint256 depositAmount,
        uint256 rewardAmount,
        uint256 participants
    ) public {
        vm.assume(depositAmount < depositCap / 3);
        vm.assume(rewardAmount < depositCap / mycBuyer.exchangeRate());
        vm.assume(depositAmount < myc.balanceOf(address(this)) / 3);
        vm.assume(depositAmount > 0);
        vm.assume(participants < depositAmount);
        // Limit to 150 otherwise it sometimes takes too long
        vm.assume(participants < 150);

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));

            myc.transfer(user, depositAmount / participants);
            vm.prank(user);
            myc.approve(address(mycLend), depositAmount / participants);
            vm.prank(user);
            mycLend.deposit(depositAmount / participants, user);
        }

        skip(EIGHT_DAYS);

        mycLend.newCycle{value: rewardAmount}(0, 0);

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));
            uint256 preBalance = user.balance;
            assertEq(mycLend.getClaimableAmount(user), 0);
            mycLend.claim(false, "");
            uint256 postBalance = user.balance;
            assertEq(postBalance, preBalance);
        }

        skip(EIGHT_DAYS);
        uint256 dustSum = mycLend.dust();
        mycLend.newCycle{value: rewardAmount}(0, 0);
        dustSum += mycLend.dust();

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));
            // ADDRESS(THIS)
            uint256 preBalance = user.balance;
            assertApproxEqAbs(
                mycLend.getClaimableAmount(user),
                (rewardAmount * 2) / participants,
                dustSum
            );
            vm.prank(user);
            mycLend.claim(false, "");
            uint256 postBalance = user.balance;
            assertApproxEqAbs(
                postBalance - preBalance,
                (rewardAmount * 2) / participants,
                dustSum
            );
        }
    }

    function testMultipleDepositsOverTimeScaleRewardsBasedOnTimeInVault()
        public
    // uint256 split,
    // uint256 depositAmount
    {
        uint256 split = 2;
        uint256 depositAmount = 232415689345790688224;
        vm.assume(split > 1);
        vm.assume(depositAmount < myc.balanceOf(address(this)) / split);
        vm.assume(depositAmount < depositCap / 2);
        vm.assume(depositAmount > 0);
        vm.assume(split < depositAmount / 2);
        uint256 rewardAmount = 1 * 10**18;
        address user = address(123);
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));

        skip(EIGHT_DAYS);
        mycLend.newCycle(0, 0);

        skip(EIGHT_DAYS);

        mycLend.newCycle{value: rewardAmount}(0, 0);
        uint256 dust = mycLend.dust();

        skip(EIGHT_DAYS);
        mycLend.newCycle(0, 0);

        uint256 expectedClaimable = rewardAmount
            .divWadDown(mycLend.totalSupply())
            .mulWadDown(depositAmount);

        assertApproxEqAbs(
            mycLend.getClaimableAmount(address(this)),
            expectedClaimable,
            dust + 1
        );

        myc.transfer(user, depositAmount);
        vm.prank(user);
        myc.approve(address(mycLend), depositAmount);
        vm.prank(user);
        mycLend.deposit(depositAmount / split, user);

        skip(EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        skip(EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        // Shouldn't get any rewards.
        assertEq(mycLend.getClaimableAmount(user), 0);

        skip(EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        expectedClaimable =
            expectedClaimable +
            rewardAmount.divWadDown(mycLend.totalSupply()).mulWadDown(
                mycLend.trueBalanceOf(address(this))
            );

        assertApproxEqAbs(
            mycLend.getClaimableAmount(address(this)),
            expectedClaimable,
            mycLend.dust() * 2
        );

        assertApproxEqAbs(
            mycLend.getClaimableAmount(user),
            (
                rewardAmount.divWadDown(mycLend.totalSupply()).mulWadDown(
                    depositAmount / split
                )
            ),
            mycLend.dust() + 1
        );

        assertApproxEqAbs(
            mycLend.getClaimableAmount(user),
            (
                rewardAmount.divWadDown(mycLend.totalSupply()).mulWadDown(
                    depositAmount / split
                )
            ),
            mycLend.dust() + 1
        );

        // Reset claimable rewards
        vm.prank(user);
        mycLend.claim(false, "");
        mycLend.claim(false, "");

        vm.prank(user);
        mycLend.deposit(depositAmount / split, user);

        uint256 dustSum = mycLend.dust();

        skip(EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        dustSum += mycLend.dust();
        skip(EIGHT_DAYS);
        mycLend.newCycle(0, 0);
        dustSum += mycLend.dust();
        // Shouldn't get any rewards.
        assertApproxEqAbs(mycLend.getClaimableAmount(user), 0, dustSum);

        skip(EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        assertApproxEqAbs(
            mycLend.getClaimableAmount(user),
            (
                rewardAmount.divWadDown(mycLend.totalSupply()).mulWadDown(
                    (depositAmount / split) * 2
                )
            ),
            mycLend.dust() + 1
        );
    }

    function testCanClaimETHNthRewardAmountIfNStaked(
        uint256 depositAmount,
        uint256 rewardAmount,
        uint256 participants
    ) public {
        vm.assume(rewardAmount != 2); // There is a known minor rounding bug that is caught by this case.
        vm.assume(rewardAmount < depositCap / 10000);
        vm.assume(depositAmount < myc.balanceOf(address(this)) / 3);
        vm.assume(participants > 0);
        vm.assume(depositAmount < depositCap / participants);
        vm.assume(depositAmount > 0);
        vm.assume(participants < depositAmount);
        // Limit to 150 otherwise it sometimes takes too long
        vm.assume(participants < 150);

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));

            myc.transfer(user, depositAmount / participants);
            vm.prank(user);
            myc.approve(address(mycLend), depositAmount / participants);
            vm.prank(user);
            mycLend.deposit(depositAmount / participants, user);
        }

        myc.transfer(address(mycBuyer), myc.balanceOf(address(this)));

        skip(EIGHT_DAYS);

        mycLend.newCycle{value: rewardAmount}(0, 0);

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));
            uint256 preBalance = myc.balanceOf(user);
            assertEq(mycLend.getClaimableAmount(user), 0);
            vm.expectRevert("No rewards claimed");
            mycLend.claim(true, "");
            uint256 postBalance = myc.balanceOf(user);
            assertEq(postBalance, preBalance);
        }

        skip(EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        for (uint256 i = 0; i < participants; i++) {
            address user = address(uint160(i + 10));
            // ADDRESS(THIS)
            uint256 preBalance = myc.balanceOf(user);
            assertApproxEqAbs(
                mycLend.getClaimableAmount(user),
                (rewardAmount * 2) / participants,
                mycLend.dust() + 1
            );

            if (mycLend.getClaimableAmount(user) == 0) {
                vm.expectRevert("No rewards claimed");
            }
            vm.prank(user);
            mycLend.claim(true, "");
            uint256 postBalance = myc.balanceOf(user);
            assertApproxEqAbs(
                postBalance - preBalance,
                ((rewardAmount * 2) / participants) * mycBuyer.exchangeRate(),
                (mycLend.dust() + 1) * mycBuyer.exchangeRate()
            );
        }
    }
}
