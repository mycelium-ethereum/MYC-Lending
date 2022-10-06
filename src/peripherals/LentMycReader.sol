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

    /// @notice External function to access internal _getCurrentCycleInfo
    function getCurrentCycleInfo(address lentMyc_, uint256 ethRewards) external view returns (uint256[] memory) {
        return _getCurrentCycleInfo(lentMyc_, ethRewards);
    }

    /// @notice Get the current cycles reward reward and info given an eth reward amount
    /// @dev Dospore
    /// @param lentMyc_ address of lentMyc
    /// @param ethRewards amount of eth that will be rewarded to current cycle stakers
    /// @return Current cycles reward info based on the given eth rewards amount
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


    /// @notice Get an arbitrary cycles info
    /// @dev Dospore
    /// @param lentMyc_ address of lentMyc
    /// @param cycle number to retrieve info on
    /// @return Given cycles reward info or the currentCycles info based on the previous cycle
    function getCycleInfo(address lentMyc_, uint256 cycle) external view returns (uint256[] memory) {
        ILentMyc lentMyc = ILentMyc(lentMyc_);
        uint256 cycle_ = lentMyc.cycle();
        bool fetchingCurrentCycle = false;
        if (cycle >= cycle_) {
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
