// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/V1/LentMyc.sol";
import {LentMycWithMigration} from "src/V2/LentMycWithMigration.sol";
import {RewardTracker} from "src/V2/RewardTracker.sol";
import {RewardDistributor} from "src/V2/RewardDistributor.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Myc} from "src/token/Myc.sol";
import {Token} from "src/token/Token.sol";
import {DummyMycBuyer} from "src/V1/DummyMycBuyer.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Migration is Test {
    using FixedPointMathLib for uint256;
    LentMyc mycLend;
    LentMycWithMigration mycLendV2;
    RewardTracker rewardTracker;
    RewardDistributor rewardDistributor;
    Myc myc;
    Token WETH;

    LentMyc impl;
    DummyMycBuyer mycBuyer;
    uint256 constant EIGHT_DAYS = 60 * 60 * 24 * 8;
    uint256 constant FOUR_DAYS = EIGHT_DAYS / 2;
    uint256 constant TWO_HOURS = 60 * 60 * 2;
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000_000 * 10**18;
    uint256 constant depositCap = INITIAL_MINT_AMOUNT;
    address constant admin = address(123);

    // So we can receive ETH rewards
    receive() external payable {}

    struct Users {
        address user;
        address user2;
        address user3;
    }

    function setUp() public {
        vm.warp(EIGHT_DAYS);
        myc = new Myc("Mycelium", "MYC", 18);
        WETH = new Token("Wrapped Ether", "WETH", 18);

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

        rewardDistributor = new RewardDistributor();
        rewardTracker = new RewardTracker();
        rewardDistributor.initialize(
            address(this),
            address(WETH),
            address(rewardTracker)
        );

        address[] memory tokenList = new address[](1);
        tokenList[0] = address(myc);
        rewardTracker.initialize(
            address(this),
            "Staked MYC",
            "sMYC",
            tokenList,
            address(rewardDistributor)
        );
        rewardTracker.setHandler(address(mycLend), true);
    }

    function testUpgradeThenMultiMigrateWithRewards(
        uint256 depositAmount,
        uint256 lossAmount,
        uint256 rewardAmount,
        uint256 tokensPerInterval,
        uint256 amountOfTimeToWaitForRewards
    ) public {
        vm.assume(depositAmount > lossAmount);
        // Div because we have to send to other users too
        vm.assume(depositAmount < rewardTracker.depositCap() / 4);
        vm.assume(rewardAmount < rewardTracker.depositCap() / 100000);
        vm.assume(tokensPerInterval < WETH.totalSupply() / 2);
        vm.assume(amountOfTimeToWaitForRewards < 60 * 60 * 24);
        vm.assume(
            tokensPerInterval * amountOfTimeToWaitForRewards <
                WETH.balanceOf(address(this)) / 2
        );
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

        vm.warp(block.timestamp + TWO_HOURS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

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

        // UPGRADE
        upgradeToV2();
        mycLendV2 = LentMycWithMigration(address(mycLend));
        address migrator = address(999);
        mycLendV2.setV2RewardTrackerAndMigrator(
            address(rewardTracker),
            migrator
        );

        address[] memory addressList = new address[](2);
        addressList[0] = address(this);
        addressList[1] = users.user;
        // Migrate address(this) and user's balance.
        vm.prank(migrator);
        mycLendV2.multiMigrate(addressList);

        // Claimable amount shouldn't change
        claimableAmount1 = mycLendV2.getClaimableAmount(address(this));
        assertApproxEqAbs(
            claimableAmount1,
            rewardAmount,
            1 + mycLendV2.dust() / 2
        );
        claimableAmount1 = mycLend.getClaimableAmount(address(this));
        assertApproxEqAbs(
            claimableAmount1,
            rewardAmount,
            1 + mycLendV2.dust() / 2
        );

        // Set rewards in new contract
        rewardDistributor.updateLastDistributionTime();
        WETH.transfer(
            address(rewardDistributor),
            tokensPerInterval * amountOfTimeToWaitForRewards
        );
        rewardDistributor.setTokensPerInterval(tokensPerInterval);
        vm.warp(block.timestamp + amountOfTimeToWaitForRewards);

        uint256 claimable = rewardTracker.claimable(users.user);
        assertApproxEqAbs(
            (tokensPerInterval * amountOfTimeToWaitForRewards) / 2,
            claimable,
            1
        );

        uint256 preBal = WETH.balanceOf(users.user);
        vm.prank(users.user);
        rewardTracker.claim(users.user);
        uint256 postBal = WETH.balanceOf(users.user);
        assertApproxEqAbs(
            preBal + (tokensPerInterval * amountOfTimeToWaitForRewards) / 2,
            postBal,
            1
        );

        claimable = rewardTracker.claimable(address(this));
        assertApproxEqAbs(
            claimable,
            (tokensPerInterval * amountOfTimeToWaitForRewards) / 2,
            1
        );

        preBal = WETH.balanceOf(address(this));
        rewardTracker.claim(address(this));
        postBal = WETH.balanceOf(address(this));
        assertApproxEqAbs(
            postBal,
            preBal + (tokensPerInterval * amountOfTimeToWaitForRewards) / 2,
            1
        );

        mycLendV2.claim(false, "");

        claimableAmount1 = mycLendV2.getClaimableAmount(address(this));
        assertEq(claimableAmount1, 0);

        // Throughout this, rewards shouldn't have changed.
        claimableAmount2 = mycLendV2.getClaimableAmount(users.user);
        assertApproxEqAbs(
            claimableAmount2,
            rewardAmount,
            1 + mycLendV2.dust() / 2
        );
    }

    function testUpgradeThenMigrateWithRewards(
        uint256 depositAmount,
        uint256 lossAmount,
        uint256 rewardAmount,
        uint256 tokensPerInterval,
        uint256 amountOfTimeToWaitForRewards
    ) public {
        vm.assume(depositAmount > lossAmount);
        // Div because we have to send to other users too
        vm.assume(depositAmount < rewardTracker.depositCap() / 4);
        vm.assume(rewardAmount < rewardTracker.depositCap() / 100000);
        vm.assume(tokensPerInterval < WETH.totalSupply() / 2);
        vm.assume(amountOfTimeToWaitForRewards < 60 * 60 * 24);
        vm.assume(
            tokensPerInterval * amountOfTimeToWaitForRewards <
                WETH.balanceOf(address(this)) / 2
        );
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

        vm.warp(block.timestamp + TWO_HOURS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

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

        // UPGRADE
        upgradeToV2();
        mycLendV2 = LentMycWithMigration(address(mycLend));
        address migrator = address(999);
        mycLendV2.setV2RewardTrackerAndMigrator(
            address(rewardTracker),
            migrator
        );
        // Migrate address(this)'s balance.
        vm.prank(migrator);
        mycLendV2.migrate(address(this));

        vm.expectRevert("User already migrated");
        vm.prank(migrator);
        mycLendV2.migrate(address(this));

        // Claimable amount shouldn't change
        claimableAmount1 = mycLendV2.getClaimableAmount(address(this));
        assertApproxEqAbs(
            claimableAmount1,
            rewardAmount,
            1 + mycLendV2.dust() / 2
        );

        // Set rewards in new contract
        rewardDistributor.updateLastDistributionTime();
        WETH.transfer(
            address(rewardDistributor),
            tokensPerInterval * amountOfTimeToWaitForRewards
        );
        rewardDistributor.setTokensPerInterval(tokensPerInterval);
        vm.warp(block.timestamp + amountOfTimeToWaitForRewards);

        uint256 claimable = rewardTracker.claimable(address(this));
        assertApproxEqAbs(
            tokensPerInterval * amountOfTimeToWaitForRewards,
            claimable,
            1
        );

        uint256 preBal = WETH.balanceOf(address(this));
        rewardTracker.claim(address(this));
        uint256 postBal = WETH.balanceOf(address(this));
        assertApproxEqAbs(
            preBal + tokensPerInterval * amountOfTimeToWaitForRewards,
            postBal,
            1
        );

        mycLendV2.claim(false, "");

        claimableAmount1 = mycLendV2.getClaimableAmount(address(this));
        assertEq(claimableAmount1, 0);

        // Throughout this, rewards shouldn't have changed.
        claimableAmount2 = mycLendV2.getClaimableAmount(users.user);
        assertApproxEqAbs(
            claimableAmount2,
            rewardAmount,
            1 + mycLendV2.dust() / 2
        );
    }

    function testV2ContractWorksStandalone(
        uint256 depositAmount,
        uint256 lossAmount,
        uint256 rewardAmount
    ) public {
        upgradeToV2();
        testE2E(depositAmount, lossAmount, rewardAmount);
    }

    function testE2EWithUpgradeHalfWayThrough(
        uint256 depositAmount,
        uint256 lossAmount,
        uint256 rewardAmount
    ) public {
        // PRE-MIGRATION (V1)
        vm.assume(depositAmount > lossAmount);
        // Div because we have to send to other users too
        vm.assume(depositAmount < INITIAL_MINT_AMOUNT / 4);
        vm.assume(rewardAmount < rewardTracker.depositCap() / 100000);
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
        upgradeToV2();
        // V2
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
            myc.balanceOf(address(this)),
            balanceBefore + expectedRedeemAmount
        );

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        balanceBefore = mycLend.trueBalanceOf(users.user);
        mycLend.setInPausedTransferMode(false);
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
            mycLend.compound(
                users.user3,
                "0x7c02520000000000000000000000000093131efee501d5721737c32576238f619548edda00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000c74fe4c715510ec2f8c61d70d397b32043f55abe00000000000000000000000093131efee501d5721737c32576238f619548edda000000000000000000000000fac9141e4f35a15dc3dac648cb542b0664cb51540000000000000000000000000000000000000000000000001bc1e3a34a9a200000000000000000000000000000000000000000000000095fbf6c9f6e64716c8300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002c000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000001bc1e3a34a9a200000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000004d0e30db0000000000000000000000000000000000000000000000000000000008000000000000000000000006a034ac28064ffa8375e4668f4ecebdf3aafcba0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000104128acb080000000000000000000000001111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000001bc1e3a34a9a200000000000000000000000000000000000000000000000000000000001000276a400000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000c74fe4c715510ec2f8c61d70d397b32043f55abe00000000000000000000000000000000000000000000000000000000cfee7c08"
            );
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

        mycLend.setPaused(true);

        vm.expectRevert("paused");
        mycLend.deposit(1, address(this));
        vm.expectRevert("paused");
        mycLend.redeem(1, address(this), address(this));
        vm.expectRevert("paused");
        mycLend.updateUser(address(this));
        vm.expectRevert("paused");
        mycLend.compound(address(this), "");
    }

    function upgradeToV2() private {
        LentMycWithMigration LMycMigration = new LentMycWithMigration();
        LMycMigration.initialize(
            address(myc),
            address(this),
            0,
            0,
            0,
            0,
            address(0)
        );
        vm.prank(admin);
        mycLend.upgradeTo(address(LMycMigration));
    }

    function testE2E(
        uint256 depositAmount,
        uint256 lossAmount,
        uint256 rewardAmount
    ) private {
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
            myc.balanceOf(address(this)),
            balanceBefore + expectedRedeemAmount
        );

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        balanceBefore = mycLend.trueBalanceOf(users.user);
        mycLend.setInPausedTransferMode(false);
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
            mycLend.compound(
                users.user3,
                "0x7c02520000000000000000000000000093131efee501d5721737c32576238f619548edda00000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000c74fe4c715510ec2f8c61d70d397b32043f55abe00000000000000000000000093131efee501d5721737c32576238f619548edda000000000000000000000000fac9141e4f35a15dc3dac648cb542b0664cb51540000000000000000000000000000000000000000000000001bc1e3a34a9a200000000000000000000000000000000000000000000000095fbf6c9f6e64716c8300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002c000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab10000000000000000000000000000000000000000000000001bc1e3a34a9a200000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000004d0e30db0000000000000000000000000000000000000000000000000000000008000000000000000000000006a034ac28064ffa8375e4668f4ecebdf3aafcba0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000104128acb080000000000000000000000001111111254fb6c44bac0bed2854e76f90643097d00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000001bc1e3a34a9a200000000000000000000000000000000000000000000000000000000001000276a400000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000004000000000000000000000000082af49447d8a07e3bd95bd0d56f35241523fbab1000000000000000000000000c74fe4c715510ec2f8c61d70d397b32043f55abe00000000000000000000000000000000000000000000000000000000cfee7c08"
            );
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

        mycLend.setPaused(true);

        vm.expectRevert("paused");
        mycLend.deposit(1, address(this));
        vm.expectRevert("paused");
        mycLend.redeem(1, address(this), address(this));
        vm.expectRevert("paused");
        mycLend.updateUser(address(this));
        vm.expectRevert("paused");
        mycLend.compound(address(this), "");
    }
}
