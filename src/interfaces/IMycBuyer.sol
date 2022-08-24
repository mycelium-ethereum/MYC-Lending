// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IMycBuyer {
    /// @dev return the amount of MYC output from MYC purchase.
    /// @dev transfer this MYC to the LentMyc contract.
    function buyMyc(bytes calldata data)
        external
        payable
        returns (uint256 mycOut);
}
