// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ILentMyc {
    function cycle() external view returns (uint256);
    function dust() external view returns (uint256);
    function cycleCumulativeEthRewards(uint256) external view returns (uint256);
    function cycleSharesAndAssets(uint256) external view returns (uint256 _totalSupply, uint256 _totalAssets);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function pendingDeposits() external view returns (uint256);
    function pendingRedeems() external view returns (uint256);

    function convertToShares(uint256 _assets, uint256 _totalAssets, uint256 _totalSupply)
        external
        view
        returns (uint256);
}
