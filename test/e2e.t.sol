// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/LentMyc.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Myc} from "src/Myc.sol";
import {DummyMycBuyer} from "src/DummyMycBuyer.sol";

contract E2E is Test {
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
    }

    struct Users {
        address user;
        address user2;
        address user3;
    }

    function testE2E(
        uint256 depositAmount,
        uint256 lossAmount,
        uint256 rewardAmount
    ) public {
        vm.assume(depositAmount > lossAmount);
        // Div because we have to send to other users too
        vm.assume(depositAmount < INITIAL_MINT_AMOUNT / 4);
        vm.assume(rewardAmount < depositCap / 100000);
        // Stack too deep :(
        Users memory users = Users({
            user: address(123),
            user2: address(1234),
            user3: address(12345)
        });

        myc.transfer(users.user, depositAmount);
        myc.approve(address(mycLend), depositAmount);
        mycLend.deposit(depositAmount, address(this));
        vm.prank(users.user);
        myc.approve(address(mycLend), depositAmount);
        vm.prank(users.user);
        mycLend.deposit(depositAmount, users.user);

        // Cycle time ended, start new cycle. 30 wei rewards. these go to last weeks stakers. Of which, there are none.
        vm.warp(block.timestamp + FOUR_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        // Now, cycle = 1. Rewards for last cycle = 0, but dust == rewardAmount

        // Get inside the preCycleTimelock window
        vm.warp(block.timestamp + EIGHT_DAYS - (TWO_HOURS / 2));
        vm.expectRevert("Deposit requests locked");
        mycLend.deposit(depositAmount, address(this));
        vm.expectRevert("Redeem requests locked");
        mycLend.redeem(depositAmount, address(this), address(this));

        vm.warp(block.timestamp + TWO_HOURS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        // Now, cycle = 2. Rewards per share for last cycle should == rewardAmount * 2 / totalSupply
        uint256 expectedRewardsPerShare = (rewardAmount * 2).divWadDown(
            mycLend.totalSupply()
        );
        // uint256 expectedRewardsPerShare = 3 * 10**13; // 0.00002 ETH
        assertEq(mycLend.cycleCumulativeEthRewards(2), expectedRewardsPerShare);

        // Rewards for each users.user should be rewardAmount (Because 2x rewardAmount has been given)

        // Allow for some rounding, because dust will always be accounted for in newCycle
        uint256 claimableAmount1 = mycLend.getClaimableAmount(address(this));
        uint256 claimableAmount2 = mycLend.getClaimableAmount(users.user);
        assertApproxEqAbs(
            claimableAmount1,
            rewardAmount,
            1 + mycLend.dust() / 2
        );
        assertApproxEqAbs(
            claimableAmount2,
            rewardAmount,
            1 + mycLend.dust() / 2
        );

        // Test claiming
        uint256 balanceBefore = address(this).balance;
        uint256 userEthBalanceBefore = users.user.balance;
        mycLend.claim(false, "");
        vm.prank(users.user);
        mycLend.claim(false, "");
        assertEq(balanceBefore + claimableAmount1, address(this).balance);
        assertEq(userEthBalanceBefore + claimableAmount2, users.user.balance);

        assertEq(mycLend.getClaimableAmount(address(this)), 0);
        assertEq(mycLend.getClaimableAmount(users.user), 0);

        // Claiming should now do nothing
        balanceBefore = address(this).balance;
        mycLend.claim(false, "");
        assertEq(address(this).balance, balanceBefore);

        // Test loss amount
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(lossAmount, 0);

        // Now the ratio of shares to underlying MYC should be (depositAmount * 2):(depositAmount * 2 - lossAmount) = 200:180 = 2:1.8 = 1:0.9
        assertEq(
            mycLend.previewRedeem(mycLend.trueBalanceOf(address(this))),
            mycLend.trueBalanceOf(address(this)).mulDivDown(
                mycLend.totalAssets(),
                mycLend.totalSupply()
            )
        );
        assertEq(
            mycLend.previewRedeem(mycLend.trueBalanceOf(users.user)),
            mycLend.trueBalanceOf(users.user).mulDivDown(
                mycLend.totalAssets(),
                mycLend.totalSupply()
            )
        );

        // Test a 3rd participant entering doesn't get anything.
        myc.transfer(users.user2, depositAmount);
        vm.prank(users.user2);
        myc.approve(address(mycLend), depositAmount);
        vm.prank(users.user2);
        mycLend.deposit(depositAmount, users.user2);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);

        mycLend.updateUser(users.user2);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);

        assertEq(mycLend.getClaimableAmount(users.user2), 0);

        // Nothing should change to do with our potential redeem
        assertEq(
            mycLend.previewRedeem(mycLend.trueBalanceOf(address(this))),
            mycLend.trueBalanceOf(address(this)).mulDivDown(
                mycLend.totalAssets(),
                mycLend.totalSupply()
            )
        );

        uint256 expectedRedeemAmount = mycLend.previewRedeem(
            mycLend.trueBalanceOf(address(this))
        );

        // Redeem
        mycLend.redeem(
            mycLend.trueBalanceOf(address(this)),
            address(this),
            address(this)
        );

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);

        balanceBefore = myc.balanceOf(address(this));
        mycLend.updateUser(address(this));
        assertEq(
            balanceBefore + expectedRedeemAmount,
            myc.balanceOf(address(this))
        );

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        balanceBefore = mycLend.trueBalanceOf(users.user);
        vm.prank(users.user);
        mycLend.transfer(users.user3, balanceBefore);

        assertEq(mycLend.balanceOf(users.user3), balanceBefore);
        assertEq(mycLend.trueBalanceOf(users.user3), balanceBefore);

        uint256 claimableAmount3 = mycLend.getClaimableAmount(users.user3);
        uint256 claimableAmount = mycLend.getClaimableAmount(users.user);
        assertEq(claimableAmount3, 0);
        uint256 user3BalanceBefore = users.user3.balance;
        balanceBefore = users.user.balance;
        vm.prank(users.user3);
        mycLend.claim(false, "");
        vm.prank(users.user);
        mycLend.claim(false, "");
        assertEq(users.user3.balance, user3BalanceBefore + claimableAmount3);
        assertEq(users.user.balance, balanceBefore + claimableAmount);

        balanceBefore = mycLend.trueBalanceOf(users.user3);
        // Set user compounding
        vm.prank(users.user3);
        mycLend.setUserAutoCompound(true);
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);
        mycLend.updateUser(users.user3);
        // Give the mycBuyer enough to swap ETH -> MYC
        myc.transfer(
            address(mycBuyer),
            mycLend.getClaimableAmount(users.user3) * mycBuyer.exchangeRate()
        );
        claimableAmount = mycLend.getClaimableAmount(users.user3);
        if (claimableAmount > 0) {
            mycLend.compound(users.user3, "");
        } else {
            vm.expectRevert("No rewards claimed");
            mycLend.compound(users.user3, "");
        }

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle(0, 0);

        // True balance should equal the balance before, plus the shares gained from the compound.
        assertEq(
            mycLend.trueBalanceOf(users.user3),
            balanceBefore +
                mycLend.previewDeposit(
                    claimableAmount * mycBuyer.exchangeRate()
                )
        );
    }
}
