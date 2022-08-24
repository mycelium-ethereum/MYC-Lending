// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMycBuyer {
    /// @dev return the amount of MYC output from MYC purchase.
    /// @dev transfer this MYC to the LentMyc contract.
    function buyMyc(uint256 ethAmount, bytes calldata data)
        external
        returns (uint256 mycOut);
}
