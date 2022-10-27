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
    Myc myc;

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
    }

    function testTransfer(uint256 depositAmount, uint256 rewardAmount) public {
        // uint256 depositAmount = 1459092071113418115754;
        // uint256 rewardAmount = 22420895;
        vm.assume(depositAmount > 0);
        vm.assume(rewardAmount > 1e18);
        vm.assume(depositAmount < INITIAL_MINT_AMOUNT / 2);
        vm.assume(rewardAmount < INITIAL_MINT_AMOUNT);
        // Div because we have to send to other users too
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
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);
        console.log(mycLend.getClaimableAmount(address(this)));

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);
        console.log(mycLend.getClaimableAmount(address(this)));
        console.log(mycLend.dust());

        console.log(1);
        assertApproxEqAbs(
            mycLend.getClaimableAmount(users.user),
            rewardAmount,
            mycLend.dust() + 1 + rewardAmount / 1e8
        );
        console.log(2);
        assertApproxEqAbs(
            mycLend.getClaimableAmount(address(this)),
            rewardAmount,
            mycLend.dust() + 1 + rewardAmount / 1e8
        );
        console.log(3);

        console.log(mycLend.getClaimableAmount(address(this)));
        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);
        console.log(mycLend.getClaimableAmount(address(this)));

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        console.log("a");
        console.log(mycLend.getClaimableAmount(address(this)));
        console.log(rewardAmount);
        console.log(rewardAmount * 2);

        mycLend.transfer(users.user2, depositAmount);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);

        vm.warp(block.timestamp + EIGHT_DAYS);
        mycLend.newCycle{value: rewardAmount}(0, 0);
        assertEq(mycLend.trueBalanceOf(address(this)), 0);
        assertEq(mycLend.trueBalanceOf(users.user2), depositAmount);

        assertApproxEqAbs(
            mycLend.getClaimableAmount(address(this)),
            rewardAmount * 2,
            mycLend.dust() + 1 + rewardAmount / 1e8
        );

        assertApproxEqAbs(
            mycLend.getClaimableAmount(users.user2),
            rewardAmount,
            mycLend.dust() + 1 + rewardAmount / 1e8
        );
    }
}
