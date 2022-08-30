// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/LentMyc.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Myc} from "src/Myc.sol";
import {DummyMycBuyer} from "src/DummyMycBuyer.sol";
import {DummyUpgrade} from "src/DummyUpgrade.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Proxy is Test {
    using FixedPointMathLib for uint256;
    LentMyc mycLend;
    Myc myc;
    DummyMycBuyer mycBuyer;
    ERC1967Proxy proxy;
    LentMyc lProxy;
    uint256 constant EIGHT_DAYS = 60 * 60 * 24 * 8;
    uint256 constant FOUR_DAYS = EIGHT_DAYS / 2;
    uint256 constant TWO_HOURS = 60 * 60 * 2;
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000_000 * 10**18;
    uint256 constant depositCap = INITIAL_MINT_AMOUNT;
    address admin = address(this);

    // So we can receive ETH rewards
    receive() external payable {}

    function setUp() public {
        vm.warp(EIGHT_DAYS);
        myc = new Myc("Mycelium", "MYC", 18);

        // Deploy Implementation
        mycLend = new LentMyc();
        mycLend.initialize(
            address(0),
            address(0),
            // 18,
            0,
            0,
            0,
            0,
            address(0)
        );

        // Deploy Proxy
        proxy = new ERC1967Proxy(address(mycLend), "");
        lProxy = LentMyc(address(proxy));
        lProxy.initialize(
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
        lProxy.setMycBuyer(address(mycBuyer));
        myc.approve(address(lProxy), myc.balanceOf(address(this)));
    }

    function testCanUpgrade() public {
        vm.expectRevert("Initializable: contract is already initialized");
        lProxy.initialize(
            address(myc),
            address(this),
            // 18,
            EIGHT_DAYS,
            block.timestamp - FOUR_DAYS,
            TWO_HOURS,
            depositCap,
            admin
        );
        DummyUpgrade dummyUpgrade = new DummyUpgrade();
        dummyUpgrade.initialize(
            address(myc),
            address(this),
            // 18,
            123,
            block.timestamp - FOUR_DAYS,
            TWO_HOURS,
            depositCap,
            admin
        );
        vm.prank(admin);
        lProxy.upgradeTo(address(dummyUpgrade));
        vm.expectRevert("test contract");
        lProxy.deposit(123, address(this));

        assertEq(lProxy.cycleLength(), EIGHT_DAYS);
    }

    function testCanUpgradeBack(uint256 rewardAmount2) public {
        DummyUpgrade dummyUpgrade = new DummyUpgrade();
        dummyUpgrade.initialize(
            address(myc),
            address(this),
            // 18,
            123,
            block.timestamp - FOUR_DAYS,
            TWO_HOURS,
            depositCap,
            admin
        );
        vm.prank(admin);
        lProxy.upgradeTo(address(dummyUpgrade));
        vm.expectRevert("test contract");
        lProxy.deposit(123, address(this));

        assertEq(lProxy.cycleLength(), EIGHT_DAYS);

        LentMyc originalImpl = new LentMyc();
        originalImpl.initialize(address(0), address(0), 0, 0, 0, 0, address(0));

        vm.prank(admin);
        lProxy.upgradeTo(address(originalImpl));

        // Then just run through a typical test, copied from elsewhere.

        address user = address(123);
        uint256 rewardAmount = 10000000000000;
        vm.assume(rewardAmount2 < depositCap / 100000);
        vm.assume(rewardAmount2 < address(this).balance / 3);

        vm.warp(block.timestamp + EIGHT_DAYS);
        lProxy.newCycle{value: rewardAmount}(0, 0);

        myc.approve(address(lProxy), type(uint256).max);
        lProxy.deposit(1000, address(this));

        vm.warp(block.timestamp + EIGHT_DAYS);
        lProxy.newCycle{value: rewardAmount}(0, 0);

        vm.warp(block.timestamp + EIGHT_DAYS);
        lProxy.newCycle(0, 0);

        myc.transfer(user, 100000 * 10**18);
        vm.prank(user);
        myc.approve(address(lProxy), type(uint256).max);
        vm.prank(user);
        // Here, cycle = 4
        lProxy.deposit(100 * 10**18, user);

        assertEq(lProxy.userLastUpdated(user), 4);

        vm.warp(block.timestamp + EIGHT_DAYS);
        lProxy.newCycle{value: rewardAmount2}(0, 0);

        assertEq(
            lProxy.getClaimableAmount(address(this)),
            rewardAmount * 2 + rewardAmount2
        );
        assertEq(lProxy.getClaimableAmount(user), 0);

        uint256 preBalance = address(this).balance;

        lProxy.claim(false, "");
        uint256 postBalance = address(this).balance;

        assertEq(postBalance - preBalance, rewardAmount * 2 + rewardAmount2);

        lProxy.updateUser(user);
        assertEq(lProxy.getClaimableAmount(user), 0);

        preBalance = user.balance;
        vm.prank(user);
        lProxy.claim(false, "");
        postBalance = user.balance;
        assertEq(postBalance - preBalance, 0);

        assertEq(lProxy.getClaimableAmount(address(this)), 0);
        assertEq(lProxy.getClaimableAmount(user), 0);

        vm.warp(block.timestamp + EIGHT_DAYS);
        lProxy.newCycle{value: rewardAmount2}(0, 0);

        // (rewardAmount2 / totalSupply) * balance
        uint256 expectedClaimable = (rewardAmount2)
            .divWadDown(lProxy.totalSupply())
            .mulWadDown(lProxy.trueBalanceOf(address(this)));

        assertApproxEqAbs(
            lProxy.getClaimableAmount(address(this)),
            expectedClaimable,
            lProxy.dust() + 1
        );

        expectedClaimable = (rewardAmount2)
            .divWadDown(lProxy.totalSupply())
            .mulWadDown(lProxy.trueBalanceOf(user));

        assertApproxEqAbs(
            lProxy.getClaimableAmount(user),
            expectedClaimable,
            lProxy.dust() + 1
        );

        uint256 trueBal = lProxy.trueBalanceOf(user);
        expectedClaimable = (rewardAmount2)
            .divWadDown(lProxy.totalSupply() + lProxy.pendingRedeems())
            .mulWadDown(trueBal);
        vm.prank(user);
        lProxy.redeem(trueBal - 1, user, user);

        vm.warp(block.timestamp + EIGHT_DAYS);
        lProxy.newCycle(0, 0);

        assertApproxEqAbs(
            lProxy.getClaimableAmount(user),
            expectedClaimable,
            lProxy.dust() + 1
        );

        uint256 oldClaimable = lProxy.getClaimableAmount(user);
        vm.warp(block.timestamp + EIGHT_DAYS);
        lProxy.newCycle{value: rewardAmount}(0, 0);
        uint256 newClaimable = lProxy.getClaimableAmount(user);
        expectedClaimable =
            expectedClaimable +
            (rewardAmount)
                .divWadDown(lProxy.totalSupply() + lProxy.pendingRedeems())
                .mulWadDown(lProxy.trueBalanceOf(user));
        assertApproxEqAbs(
            lProxy.getClaimableAmount(user),
            expectedClaimable,
            lProxy.dust() + 1
        );

        assertApproxEqAbs(
            newClaimable - oldClaimable,
            rewardAmount.divWadDown(lProxy.totalSupply()).mulWadDown(1),
            0
        );
    }
}
