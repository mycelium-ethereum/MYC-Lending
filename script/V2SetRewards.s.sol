// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/V1/LentMyc.sol";
import {RewardDistributor} from "src/V2/RewardDistributor.sol";

contract SetRewardsV2 is Script {
    uint256 tokensPerInterval = 1e18;

    function setUp() public {}

    function run() public {
        address distributorAddr = vm.envAddress("REWARD_DISTRIBUTOR_PROXY");
        RewardDistributor distributor = RewardDistributor(distributorAddr);

        vm.startBroadcast();
        // Note that in prod updateLastDistributionTime should only be directly called once.
        distributor.updateLastDistributionTime();
        distributor.setTokensPerInterval(tokensPerInterval);

        vm.stopBroadcast();
    }
}
