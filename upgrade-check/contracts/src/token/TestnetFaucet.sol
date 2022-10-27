// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

contract TestnetFaucet {
    ERC20 public myc;
    mapping(address => uint256) lastClaimed;

    constructor(address _myc) {
        myc = ERC20(_myc);
    }

    function drip() external {
        require(
            block.timestamp - lastClaimed[msg.sender] > 10 * 60,
            "1 claim per 10 mins max"
        );
        lastClaimed[msg.sender] = block.timestamp;
        myc.transfer(msg.sender, 1000 * 10**18);
    }
}
