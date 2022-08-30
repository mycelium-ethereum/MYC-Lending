// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LentMyc} from "src/LentMyc.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Myc} from "src/Myc.sol";
import {DummyMycBuyer} from "src/DummyMycBuyer.sol";
import {DummyUpgrade} from "src/DummyUpgrade.sol";
import {UpgradeProxy} from "foundry-upgrades/utils/UpgradeProxy.sol";
import {TransparentUpgradeableProxy} from "openzeppelin/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ERC1967Proxy} from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract Proxy is Test {
    using FixedPointMathLib for uint256;
    LentMyc mycLend;
    Myc myc;
    DummyMycBuyer mycBuyer;
    UpgradeProxy deploy;
    ERC1967Proxy proxy;
    LentMyc lProxy;
    uint256 constant EIGHT_DAYS = 60 * 60 * 24 * 8;
    uint256 constant FOUR_DAYS = EIGHT_DAYS / 2;
    uint256 constant TWO_HOURS = 60 * 60 * 2;
    uint256 constant INITIAL_MINT_AMOUNT = 1_000_000_000 * 10**18;
    uint256 constant depositCap = INITIAL_MINT_AMOUNT;
    address constant admin = address(1234);

    enum ProxyType {
        UUPS,
        BeaconProxy,
        Beacon,
        Transparent
    }

    // So we can receive ETH rewards
    receive() external payable {}

    function setUp() public {
        vm.warp(EIGHT_DAYS);
        myc = new Myc("Mycelium", "MYC", 18);

        deploy = new UpgradeProxy();

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

        /*
        address(proxy).call(
            abi.encodeWithSignature("upgradeTo(address)", address(dummyUpgrade))
        );

        vm.expectRevert("test contract");
        address(proxy).call(
            abi.encodeWithSignature(
                "deposit(uint256address)",
                123,
                address(this)
            )
        );
        */
    }

    function testCanUpgradeBack() public {
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

        /*
        deploy.upgrade(address(dummyUpgrade), address(123123), address(0));

        LentMyc second = new LentMyc();
        // second.initialize()

        deploy.upgrade(address(second), address(123123), address(0));

        myc.approve(address(mycLend), 123);
        mycLend.deposit(123, address(this));
        assertEq(mycLend.userPendingDeposits(address(this)), 123);

        mycLend = new LentMyc();

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

        myc.approve(address(mycLend), 123);
        mycLend.deposit(123, address(this));
        assertEq(mycLend.cycleLength(), EIGHT_DAYS);

        LentMyc mycLend2 = new LentMyc();

        mycLend2.initialize(
            address(myc),
            address(this),
            // 18,
            123,
            block.timestamp - FOUR_DAYS,
            TWO_HOURS,
            depositCap
        );

        console.log(0);
        mycLend.upgradeTo(address(mycLend2));
        console.log(123);
        myc.approve(address(mycLend), 123);
        console.log(123);
        mycLend.deposit(123, address(this));
        console.log(456);
        assertEq(mycLend.cycleLength(), 123);
    */
    }
}
