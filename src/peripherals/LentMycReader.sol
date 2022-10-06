// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ILentMyc} from "../interfaces/ILentMyc.sol";

/**
 * @title MYC Lending contract reader
 * @author Dospore
 */
contract LentMycReader {
    using FixedPointMathLib for uint256;

    struct CycleInfo {
        uint256 totalSupply;
        uint256 totalAssets;
    }

    /// get the current cycles apr
    function getCurrentCycleInfo(address lentMyc_, uint256 ethRewards) external view returns (uint256[] memory) {
        return _getCurrentCycleInfo(lentMyc_, ethRewards);
    }

    function _getCurrentCycleInfo(address lentMyc_, uint256 ethRewards) internal view returns (uint256[] memory) {
        ILentMyc lentMyc = ILentMyc(lentMyc_);

        uint256 dust = lentMyc.dust();
        uint256 pendingRedeems = lentMyc.pendingRedeems();

        uint256 currentCycleSupply = lentMyc.totalSupply() + pendingRedeems;
        uint256 currentCycleMyc = lentMyc.totalAssets();

        uint256 currentCyclesEthRewardsPerShare = (ethRewards + dust).divWadDown(currentCycleSupply);

        uint256[] memory info;
        info[0] = currentCyclesEthRewardsPerShare;
        info[1] = currentCycleSupply;
        info[2] = currentCycleMyc;

        return info;
    }



    /// Fetches
    function getCycleInfo(address lentMyc_, uint256 cycle) external view returns (uint256[] memory) {
        ILentMyc lentMyc = ILentMyc(lentMyc_);
        uint256 cycle_ = lentMyc.cycle();
        bool fetchingCurrentCycle = false;
        if (cycle >= cycle_) {
            // set to cycle_ - 1
            cycle = cycle_ - 1;
            fetchingCurrentCycle = true;
        }

        uint256 previousCumaltiveEthRewardsPerShare = lentMyc.cycleCumulativeEthRewards(cycle - 1);
        uint256 cyclesCumaltiveEthRewardsPerShare = lentMyc.cycleCumulativeEthRewards(cycle);
        uint256 cyclesEthRewardsPerShare = previousCumaltiveEthRewardsPerShare - cyclesCumaltiveEthRewardsPerShare;

        (uint256 cycleSupply, uint256 cycleMyc) =  lentMyc.cycleSharesAndAssets(cycle);


        if (fetchingCurrentCycle) {
            uint256 lastCyclesEthRewards = cyclesEthRewardsPerShare.mulWadDown(cycleSupply);
            return _getCurrentCycleInfo(lentMyc_, lastCyclesEthRewards);
        }

        uint256[] memory info;
        info[0] = cyclesEthRewardsPerShare;
        info[1] = cycleSupply;
        info[2] = cycleMyc;

        return info;
    }
}
