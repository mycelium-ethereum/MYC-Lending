// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {IMycBuyer} from "interfaces/IMycBuyer.sol";

contract DummyMycBuyer is IMycBuyer {
    // 1 ETH = `exchangeRate` MYC
    uint256 public exchangeRate = 10000;

    function buyMyc(bytes calldata data)
        external
        payable
        returns (uint256 mycOut)
    {}
}
