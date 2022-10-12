import {LentMyc} from "./LentMyc.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DummyUpgrade is LentMyc {
    function deposit(uint256, address) public pure override {
        revert("test contract");
    }
}
