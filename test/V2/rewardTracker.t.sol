// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {RewardTracker} from "src/V2/RewardTracker.sol";
import {RewardDistributor} from "src/V2/RewardDistributor.sol";
import {Myc} from "src/token/Myc.sol";
import {Token} from "src/token/Token.sol";
import {DummyMycBuyer} from "src/V1/DummyMycBuyer.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RewardTrackerTest is Test {
    Myc myc;
    Myc esMyc;
    Token WETH;
    RewardTracker rewardTracker;
    RewardDistributor rewardDistributor;
    Users users;

    struct Users {
        address user;
        address user2;
        address user3;
        address user4;
    }

    function setUp() public {
        users = Users({
            user: address(123),
            user2: address(1234),
            user3: address(12345),
            user4: address(123456)
        });
        myc = new Myc("Mycelium", "MYC", 18);
        esMyc = new Myc("Escrowed Mycelium", "esMYC", 18);
        WETH = new Token("Wrapped Ether", "WETH", 18);

        // Proxy implementations
        RewardDistributor distributorImpl = new RewardDistributor();
        address[] memory emptyList = new address[](0);
        distributorImpl.initialize(address(0), address(0), address(0));
        RewardTracker trackerImpl = new RewardTracker();
        trackerImpl.initialize(address(0), "", "", emptyList, address(0));

        // Proxies
        ERC1967Proxy trackerProxy = new ERC1967Proxy(address(trackerImpl), "");
        rewardTracker = RewardTracker(address(trackerProxy));
        ERC1967Proxy distribProxy = new ERC1967Proxy(
            address(distributorImpl),
            ""
        );
        rewardDistributor = RewardDistributor(address(distribProxy));

        rewardDistributor.initialize(
            address(this),
            address(WETH),
            address(rewardTracker)
        );
        rewardDistributor.updateLastDistributionTime();
        WETH.transfer(address(rewardDistributor), 1000000 * 1e18);

        address[] memory tokenList = new address[](2);
        tokenList[0] = address(myc);
        tokenList[1] = address(esMyc);
        rewardTracker.initialize(
            address(this),
            "Staked MYC",
            "sMYC",
            tokenList,
            address(rewardDistributor)
        );
    }

    function testInits() public {
        assertEq(rewardTracker.isInitialized(), true);
        assertEq(rewardTracker.isDepositToken(address(this)), false);
        assertEq(rewardTracker.isDepositToken(address(myc)), true);
        assertEq(rewardTracker.isDepositToken(address(esMyc)), true);
        assertEq(rewardTracker.distributor(), address(rewardDistributor));
        assertEq(rewardTracker.rewardToken(), address(WETH));
        address[] memory tokenList = new address[](2);
        tokenList[0] = address(myc);
        tokenList[1] = address(esMyc);
        vm.expectRevert("RewardTracker: already initialized");
        rewardTracker.initialize(
            address(this),
            "staked myc",
            "sMYC",
            tokenList,
            address(rewardDistributor)
        );
    }

    function testCannotWithdrawTokenAsNonGov() public {
        vm.expectRevert("Governable: forbidden");
        vm.prank(address(123123));
        rewardTracker.withdrawToken(address(myc), address(1), 100);
    }

    function testWithdrawToken() public {
        myc.transfer(address(rewardTracker), 100);
        uint256 preBal = myc.balanceOf(address(this));
        rewardTracker.withdrawToken(address(myc), address(this), 100);
        uint256 postBal = myc.balanceOf(address(this));
        assertEq(postBal, preBal + 100);
    }

    function testSetDepositToken() public {
        vm.expectRevert("Governable: forbidden");
        vm.prank(users.user);
        rewardTracker.setDepositToken(users.user2, true);

        rewardTracker.setGov(users.user);

        assertEq(rewardTracker.isDepositToken(users.user2), false);
        vm.prank(users.user);
        rewardTracker.setDepositToken(users.user2, true);
        assertEq(rewardTracker.isDepositToken(users.user2), true);
        vm.prank(users.user);
        rewardTracker.setDepositToken(users.user2, false);
        assertEq(rewardTracker.isDepositToken(users.user2), false);
    }

    function testSetInPrivateTransferMode(bool value) public {
        vm.expectRevert("Governable: forbidden");
        vm.prank(users.user);
        rewardTracker.setInPrivateTransferMode(value);

        rewardTracker.setGov(users.user);

        assertEq(rewardTracker.inPrivateTransferMode(), false);
        vm.prank(users.user);
        rewardTracker.setInPrivateTransferMode(value);
        assertEq(rewardTracker.inPrivateTransferMode(), value);
    }

    // function testDepositCap(uint256 depositCap, uint256 depositAmount) public {
    function testDepositCap() public {
        uint256 depositCap = 0;
        uint256 depositAmount = 1;
        vm.assume(depositCap < depositAmount);
        rewardDistributor.setTokensPerInterval(20667989410000000); // 0.02066798941 esMyc per second
        rewardTracker.setDepositCap(depositCap);
        vm.expectRevert("RewardTracker: depositCap exceeded");
        rewardTracker.stake(address(myc), depositAmount);
    }

    function testStakeUnstakeClaim() public {
        rewardTracker.setDepositCap(type(uint256).max);
        rewardDistributor.setTokensPerInterval(20667989410000000); // 0.02066798941 esMyc per second
        myc.transfer(users.user, 1e18 * (1000));
        esMyc.transfer(users.user, 1e18 * (1000));

        rewardTracker.setInPrivateStakingMode(true);
        vm.expectRevert("RewardTracker: action not enabled");
        vm.prank(users.user);
        rewardTracker.stake(address(myc), 1e18 * (1000));

        rewardTracker.setInPrivateStakingMode(false);

        vm.expectRevert("RewardTracker: invalid _amount");
        vm.prank(users.user);
        rewardTracker.stake(users.user2, 0);

        vm.expectRevert("RewardTracker: invalid _depositToken");
        vm.prank(users.user);
        rewardTracker.stake(users.user2, 1e18 * (1000));

        vm.expectRevert(stdError.arithmeticError);
        vm.prank(users.user);
        rewardTracker.stake(address(myc), 1e18 * (1000));

        vm.prank(users.user);
        myc.approve(address(rewardTracker), 1e18 * (1000));
        vm.prank(users.user);
        rewardTracker.stake(address(myc), 1e18 * (1000));
        assertEq(rewardTracker.stakedAmounts(users.user), 1e18 * (1000));
        assertEq(
            rewardTracker.depositBalances(users.user, address(myc)),
            1e18 * (1000)
        );

        vm.warp(block.timestamp + 24 * 60 * 60);

        assert(rewardTracker.claimable(users.user) > 1e18 * (1785)); // 50000 / 28 => ~1785
        assert(rewardTracker.claimable(users.user) < 1e18 * (1786));

        esMyc.transfer(users.user2, 1e18 * (500));
        vm.prank(users.user2);
        esMyc.approve(address(rewardTracker), 1e18 * (500));
        vm.prank(users.user2);
        rewardTracker.stake(address(esMyc), 1e18 * (500));
        assertEq(rewardTracker.stakedAmounts(users.user2), 1e18 * (500));
        assertEq(rewardTracker.stakedAmounts(users.user), 1e18 * (1000));
        assertEq(
            rewardTracker.depositBalances(users.user, address(myc)),
            1e18 * (1000)
        );
        assertEq(rewardTracker.depositBalances(users.user, address(esMyc)), 0);
        assertEq(rewardTracker.depositBalances(users.user2, address(myc)), 0);
        assertEq(
            rewardTracker.depositBalances(users.user2, address(esMyc)),
            1e18 * (500)
        );
        assertEq(
            rewardTracker.totalDepositSupply(address(esMyc)),
            1e18 * (500)
        );
        assertEq(rewardTracker.totalDepositSupply(address(myc)), 1e18 * 1000);

        assertEq(rewardTracker.averageStakedAmounts(users.user), 0);
        assertEq(rewardTracker.cumulativeRewards(users.user), 0);
        assertEq(rewardTracker.averageStakedAmounts(users.user2), 0);
        assertEq(rewardTracker.cumulativeRewards(users.user2), 0);

        vm.warp(block.timestamp + (24 * 60 * 60));

        assert(rewardTracker.claimable(users.user) > 1e18 * (1785 + 1190));
        assert(rewardTracker.claimable(users.user) < 1e18 * (1786 + 1191));

        assert(rewardTracker.claimable(users.user2) > 1e18 * (595));
        assert(rewardTracker.claimable(users.user2) < 1e18 * (596));

        vm.expectRevert("RewardTracker: _amount exceeds stakedAmount");
        vm.prank(users.user);
        rewardTracker.unstake(address(esMyc), 1e18 * (1001));

        vm.expectRevert("RewardTracker: _amount exceeds depositBalance");
        vm.prank(users.user);
        rewardTracker.unstake(address(esMyc), 1e18 * (1000));

        vm.expectRevert("RewardTracker: _amount exceeds stakedAmount");
        vm.prank(users.user);
        rewardTracker.unstake(address(myc), 1e18 * (1001));

        assertEq(myc.balanceOf(users.user), 0);
        vm.prank(users.user);
        rewardTracker.unstake(address(myc), 1e18 * (1000));
        assertEq(myc.balanceOf(users.user), 1e18 * (1000));
        assertEq(rewardTracker.totalDepositSupply(address(myc)), 0);
        assertEq(
            rewardTracker.totalDepositSupply(address(esMyc)),
            1e18 * (500)
        );

        assertEq(rewardTracker.averageStakedAmounts(users.user), 1e18 * (1000));
        assert(
            rewardTracker.cumulativeRewards(users.user) > 1e18 * (1785 + 1190)
        );
        assert(
            rewardTracker.cumulativeRewards(users.user) < 1e18 * (1786 + 1191)
        );
        assertEq(rewardTracker.averageStakedAmounts(users.user2), 0);
        assertEq(rewardTracker.cumulativeRewards(users.user2), 0);

        uint256 preBal = esMyc.balanceOf(users.user);

        vm.expectRevert("RewardTracker: _amount exceeds stakedAmount");
        vm.prank(users.user);
        rewardTracker.unstake(address(myc), 1);
        uint256 postBal = esMyc.balanceOf(users.user);

        assertEq(postBal - preBal, 0);
        assertEq(WETH.balanceOf(users.user), 0);
        vm.prank(users.user);
        rewardTracker.claim(users.user3);
        assert(WETH.balanceOf(users.user3) > 1e18 * (1785 + 1190));
        assert(WETH.balanceOf(users.user3) < 1e18 * (1786 + 1191));

        vm.warp(block.timestamp + 24 * 60 * 60);

        assertEq(rewardTracker.claimable(users.user), 0);

        assert(rewardTracker.claimable(users.user2) > 1e18 * (595 + 1785));
        assert(rewardTracker.claimable(users.user2) < 1e18 * (596 + 1786));

        myc.transfer(users.user2, 1e18 * (300));
        vm.prank(users.user2);
        myc.approve(address(rewardTracker), 1e18 * (300));
        vm.prank(users.user2);
        rewardTracker.stake(address(myc), 1e18 * (300));
        assertEq(rewardTracker.totalDepositSupply(address(myc)), 1e18 * (300));
        assertEq(
            rewardTracker.totalDepositSupply(address(esMyc)),
            1e18 * (500)
        );

        assertEq(rewardTracker.averageStakedAmounts(users.user), 1e18 * (1000));
        assert(
            rewardTracker.cumulativeRewards(users.user) > 1e18 * (1785 + 1190)
        );
        assert(
            rewardTracker.cumulativeRewards(users.user) < 1e18 * (1786 + 1191)
        );
        assertEq(rewardTracker.averageStakedAmounts(users.user2), 1e18 * (500));
        assert(
            rewardTracker.cumulativeRewards(users.user2) > 1e18 * (595 + 1785)
        );
        assert(
            rewardTracker.cumulativeRewards(users.user2) < 1e18 * (596 + 1786)
        );

        vm.expectRevert("RewardTracker: _amount exceeds depositBalance");
        vm.prank(users.user2);
        rewardTracker.unstake(address(myc), 1e18 * (301));

        vm.expectRevert("RewardTracker: _amount exceeds depositBalance");
        vm.prank(users.user2);
        rewardTracker.unstake(address(esMyc), 1e18 * (501));

        vm.warp(block.timestamp + 2 * 24 * 60 * 60);

        vm.prank(users.user);
        rewardTracker.claim(users.user3);
        vm.prank(users.user2);
        rewardTracker.claim(users.user4);

        assertEq(rewardTracker.averageStakedAmounts(users.user), 1e18 * (1000));
        assert(
            rewardTracker.cumulativeRewards(users.user) > 1e18 * (1785 + 1190)
        );
        assert(
            rewardTracker.cumulativeRewards(users.user) < 1e18 * (1786 + 1191)
        );
        assert(rewardTracker.averageStakedAmounts(users.user2) > 1e18 * (679));
        assert(rewardTracker.averageStakedAmounts(users.user2) < 1e18 * (681));
        assert(
            rewardTracker.cumulativeRewards(users.user2) >
                1e18 * (595 + 1785 + 1785 * 2)
        );
        assert(
            rewardTracker.cumulativeRewards(users.user2) <
                1e18 * (596 + 1786 + 1786 * 2)
        );

        vm.warp(block.timestamp + 2 * 24 * 60 * 60);

        vm.prank(users.user);
        rewardTracker.claim(users.user3);
        vm.prank(users.user2);
        rewardTracker.claim(users.user4);

        assertEq(rewardTracker.averageStakedAmounts(users.user), 1e18 * (1000));
        assert(
            rewardTracker.cumulativeRewards(users.user) > 1e18 * (1785 + 1190)
        );
        assert(
            rewardTracker.cumulativeRewards(users.user) < 1e18 * (1786 + 1191)
        );
        assert(rewardTracker.averageStakedAmounts(users.user2) > 1e18 * (724));
        assert(rewardTracker.averageStakedAmounts(users.user2) < 1e18 * (726));
        assert(
            rewardTracker.cumulativeRewards(users.user2) >
                1e18 * (595 + 1785 + 1785 * 4)
        );
        assert(
            rewardTracker.cumulativeRewards(users.user2) <
                1e18 * (596 + 1786 + 1786 * 4)
        );

        assertEq(
            WETH.balanceOf(users.user3),
            rewardTracker.cumulativeRewards(users.user)
        );
        assertEq(
            WETH.balanceOf(users.user4),
            rewardTracker.cumulativeRewards(users.user2)
        );

        assertEq(myc.balanceOf(users.user2), 0);
        assertEq(esMyc.balanceOf(users.user2), 0);
        vm.prank(users.user2);
        rewardTracker.unstake(address(myc), 1e18 * (300));
        assertEq(myc.balanceOf(users.user2), 1e18 * (300));
        assertEq(esMyc.balanceOf(users.user2), 0);
        vm.prank(users.user2);
        rewardTracker.unstake(address(esMyc), 1e18 * (500));
        assertEq(myc.balanceOf(users.user2), 1e18 * (300));
        assertEq(esMyc.balanceOf(users.user2), 1e18 * (500));
        assertEq(rewardTracker.totalDepositSupply(address(myc)), 0);
        assertEq(rewardTracker.totalDepositSupply(address(esMyc)), 0);
    }

    function testSetsHandler(address handler) public {
        rewardTracker.setHandler(handler, true);
        assertEq(rewardTracker.isHandler(handler), true);
    }
}
