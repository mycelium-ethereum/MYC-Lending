// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/V1/LentMyc.sol";
import {Myc} from "src/token/Myc.sol";
import {Token} from "src/token/Token.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LentMyc} from "src/V1/LentMyc.sol";
import {LentMycWithMigration} from "src/V2/LentMycWithMigration.sol";
import {RewardTracker} from "src/V2/RewardTracker.sol";
import {RewardDistributor} from "src/V2/RewardDistributor.sol";
import {TestnetFaucet} from "src/token/TestnetFaucet.sol";

contract MigrateV1Script is Script {
    address gov;
    address admin;
    uint256 decimals = 18;
    uint256 cycleLength = 300;
    uint256 firstCycleStart = block.timestamp;
    uint256 preCycleTimelock = 60;
    uint256 depositCap = 100000000000000000000000;

    function setUp() public {}

    function run() public {
        // LMYC env var should be set. Deploy with V1Deploy.s.sol.
        gov = msg.sender;
        admin = msg.sender;
        address lProxyAddr = vm.envAddress("LMYC");
        address myc = vm.envAddress("MYC");
        address esMyc = vm.envAddress("esMYC");
        address WETH = vm.envAddress("WETH");

        LentMyc lProxy = LentMyc(lProxyAddr);
        Token weth = Token(WETH);
        Token mycToken = Token(myc);

        vm.startBroadcast();

        lProxy.setPaused(true);
        lProxy.setInPausedTransferMode(true);

        LentMycWithMigration lMycMigration = new LentMycWithMigration();
        // Initialize the implementation.
        lMycMigration.initialize(
            address(0),
            address(0),
            0,
            0,
            0,
            0,
            address(0)
        );

        // Deploy new staking contracts.
        RewardTracker trackerImpl = new RewardTracker();
        RewardDistributor distributorImpl = new RewardDistributor();

        address[] memory empty = new address[](0);
        // Initialize the implementations.
        trackerImpl.initialize(address(0), "", "", empty, address(0));
        distributorImpl.initialize(address(0), address(0), address(0));

        ERC1967Proxy proxy = new ERC1967Proxy(address(trackerImpl), "");
        RewardTracker trackerProxy = RewardTracker(address(proxy));

        proxy = new ERC1967Proxy(address(distributorImpl), "");
        RewardDistributor distributorProxy = RewardDistributor(address(proxy));

        console.log(address(trackerProxy));
        console.log(address(distributorProxy));

        {
            address[] memory mycEsMyc = new address[](2);
            mycEsMyc[0] = myc;
            mycEsMyc[1] = esMyc;

            trackerProxy.initialize(
                gov,
                "Staked MYC",
                "sMYC",
                mycEsMyc,
                address(distributorProxy)
            );
        }
        distributorProxy.initialize(gov, WETH, address(trackerProxy));

        lProxy.upgradeTo(address(lMycMigration));

        LentMycWithMigration lProxy2 = LentMycWithMigration(address(lProxy));

        lProxy2.setDepositWithdrawPaused(true);

        lProxy2.setV2RewardTrackerAndMigrator(address(trackerProxy), gov);
        trackerProxy.setHandler(address(lProxy2), true);
        trackerProxy.setInPrivateTransferMode(true);
        trackerProxy.setDepositCap(100000000000000000000000000);

        lProxy2.setPaused(false);
        weth.transfer(address(distributorProxy), weth.balanceOf(gov));

        console.log(
            "export REWARD_TRACKER_PROXY=%s; "
            "export REWARD_DISTRIBUTOR_PROXY=%s; "
            "export REWARD_TRACKER_IMPL=%s; ",
            address(trackerProxy),
            address(distributorProxy),
            address(trackerImpl)
        );
        console.log(
            "export REWARD_DISTRIBUTOR_IMPL=%s",
            address(distributorImpl)
        );

        mycToken.approve(address(trackerProxy), type(uint256).max);
        trackerProxy.stake(myc, 1000);

        vm.stopBroadcast();
    }
}
