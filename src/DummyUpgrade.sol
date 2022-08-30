import {LentMyc} from "./LentMyc.sol";

import "forge-std/console.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract DummyUpgrade is LentMyc {
    function deposit(uint256, address) public override {
        console.log(2);
        revert("test contract");
    }
}
