// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

contract Governable {
    address public gov;

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        gov = _gov;
    }
}
