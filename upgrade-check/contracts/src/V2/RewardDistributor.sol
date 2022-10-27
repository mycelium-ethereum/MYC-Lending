// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "../interfaces/IRewardDistributor.sol";
import "../interfaces/IRewardTracker.sol";
import "../access/Governable.sol";

contract RewardDistributor is
    IRewardDistributor,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    Governable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public override rewardToken;
    uint256 public override tokensPerInterval;
    uint256 public lastDistributionTime;
    address public rewardTracker;
    bool public isInitialized;

    event Distribute(uint256 amount);
    event TokensPerIntervalChange(uint256 amount);

    function initialize(
        address _gov,
        address _rewardToken,
        address _rewardTracker
    ) external {
        require(!isInitialized, "RewardTracker: already initialized");
        isInitialized = true;
        rewardToken = _rewardToken;
        rewardTracker = _rewardTracker;
        gov = _gov;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(
        address _token,
        address _account,
        uint256 _amount
    ) external onlyGov {
        IERC20Upgradeable(_token).safeTransfer(_account, _amount);
    }

    function updateLastDistributionTime() external onlyGov {
        lastDistributionTime = block.timestamp;
    }

    function setTokensPerInterval(uint256 _amount) external onlyGov {
        require(
            lastDistributionTime != 0,
            "RewardDistributor: invalid lastDistributionTime"
        );
        IRewardTracker(rewardTracker).updateRewards();
        tokensPerInterval = _amount;
        emit TokensPerIntervalChange(_amount);
    }

    function pendingRewards() public view override returns (uint256) {
        if (block.timestamp == lastDistributionTime) {
            return 0;
        }

        uint256 timeDiff = block.timestamp - lastDistributionTime;
        return tokensPerInterval * timeDiff;
    }

    function distribute() external override returns (uint256) {
        require(
            msg.sender == rewardTracker,
            "RewardDistributor: invalid msg.sender"
        );
        uint256 amount = pendingRewards();
        if (amount == 0) {
            return 0;
        }

        lastDistributionTime = block.timestamp;

        uint256 balance = IERC20Upgradeable(rewardToken).balanceOf(
            address(this)
        );
        if (amount > balance) {
            amount = balance;
        }

        IERC20Upgradeable(rewardToken).safeTransfer(msg.sender, amount);

        emit Distribute(amount);
        return amount;
    }

    function _authorizeUpgrade(
        address /*newImplementation*/
    ) internal view override {
        require(msg.sender == gov, "onlyGov");
    }
}
