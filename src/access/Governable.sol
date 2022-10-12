// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

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
