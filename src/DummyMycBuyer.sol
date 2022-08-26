// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {IMycBuyer} from "interfaces/IMycBuyer.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

contract DummyMycBuyer is IMycBuyer {
    // 1 ETH = `exchangeRate` MYC
    uint256 public exchangeRate = 10000;
    ERC20 public myc;
    address public gov;

    constructor(address _myc, address _gov) {
        myc = ERC20(_myc);
        gov = _gov;
    }

    /**
     * @notice JUST A DUMMY FUNCTION -> not a real implementation.
     */
    function buyMyc(
        bytes calldata /*data*/
    ) external payable returns (uint256) {
        uint256 mycOut = msg.value * exchangeRate;
        require(myc.balanceOf(address(this)) >= mycOut, "Not enough balance");
        myc.transfer(msg.sender, mycOut);
        return mycOut;
    }

    function withdrawEth() external {
        require(msg.sender == gov, "msg.sender != gov");
        Address.sendValue(payable(msg.sender), address(this).balance);
    }
}
