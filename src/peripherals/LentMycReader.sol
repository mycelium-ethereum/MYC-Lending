// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ILentMyc} from "../interfaces/ILentMyc.sol";

/**
 * @title MYC Lending contract reader
 * @author Dospore.
 */
contract LentMycReader {
    using FixedPointMathLib for uint256;

    struct CycleInfo {
        uint256 ethRewardsPerShare;
        uint256 supply;
        uint256 assets;
    }

    /**
     * @notice External function to access internal _getCurrentCycleInfo.
     */
    function getCurrentCycleInfo(address lentMyc_, uint256 ethRewards) external view returns (CycleInfo memory) {
        return _getCurrentCycleInfo(lentMyc_, ethRewards);
    }

    /**
     * @notice Get the current cycles reward reward and info given an eth reward amount.
     * @param lentMyc_ address of lentMyc.
     * @param ethRewards amount of eth that will be rewarded to current cycle stakers.
     * @return Current cycles reward info based on the given eth rewards amount.
     */
    function _getCurrentCycleInfo(address lentMyc_, uint256 ethRewards) internal view returns (CycleInfo memory) {
        ILentMyc lentMyc = ILentMyc(lentMyc_);

        uint256 dust = lentMyc.dust();
        uint256 pendingRedeems = lentMyc.pendingRedeems();

        uint256 currentCycleSupply = lentMyc.totalSupply() + pendingRedeems;
        uint256 currentCycleMyc = lentMyc.totalAssets();

        uint256 currentCyclesEthRewardsPerShare = (ethRewards + dust).divWadDown(currentCycleSupply);

        CycleInfo memory info = CycleInfo({
            ethRewardsPerShare: currentCyclesEthRewardsPerShare,
            supply: currentCycleSupply,
            assets: currentCycleMyc
        });

        return info;
    }

    /**
     * @notice Get an arbitrary cycle's info.
     * @param lentMyc_ address of lentMyc.
     * @param cycle number to retrieve info on.
     * @return Given cycles reward info or the currentCycles info based on the previous cycle.
     */
    function getCycleInfo(address lentMyc_, uint256 cycle) external view returns (CycleInfo memory) {
        ILentMyc lentMyc = ILentMyc(lentMyc_);
        uint256 currentCycle = lentMyc.cycle();
        bool fetchingCurrentCycle = false;
        if (cycle >= currentCycle) {
            cycle = currentCycle - 1;
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

        CycleInfo memory info = CycleInfo({
            ethRewardsPerShare: cyclesEthRewardsPerShare,
            supply: cycleSupply,
            assets: cycleMyc
        });

        return info;
    }
}
