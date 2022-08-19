// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "solmate/mixins/ERC4626.sol";

contract MYCLendArbitrum is ERC4626 {
    address deployer;
    address pendingNewDeployer;
    uint256 amountDeployed;
    uint256 totalWithdrawAmountRequested;
    // Amount of time each cycle lasts for.
    uint256 cycleLength;
    // The zero-indexed count of cycle.
    uint256 cycleNumber;
    // The time at which the current cycle started.
    uint256 cycleStart;
    /// @notice The amount of time before the cycle starts before users must deposit to be included in next week's rewards.
    /// @notice That is, the
    uint256 preCycleTimelock;

    // TODO what happens if a user deposits after cycleStart - preCycleTimelock, and then they get a week of rewards but their MYC isn't being used for anything?
    // Most obvious solution:
    // Minimum deposited time = 1 cycle. So if you deposit after the start of a cycle you can't withdraw until the end of the *next* cycle.
    //     - Note: this would mean users, if they already have some deposited, then deposit some more, redeems for their initial amount would be locked.
    //       Writing the logic to counteract this would introduce substantial complexities. Will not do.
    // Another solution: They deposit, but it goes into a separate "pending deposits" contract, which gets transferred in for next one.

    /// @notice Amount pending to be deposited by users.
    mapping(address => uint256) userPendingDeposits;

    uint256 withdrawDelay;

    uint256 public _totalAssets;

    uint256 lastUpdatedTime;
    /// @notice The amount of tokens to emit per second.
    /// @notice The contract will keep emitting this many until `deployer` calls `setTokensPerSecond` again.
    uint256 tokensPerSecond;

    /// @notice If true, denominate a user's rewards in ETH. If false, denominate in MYC.
    /// @dev Every address defaults to 0 (false).
    mapping(address => bool) userClaimInETH;
    ///
    mapping(address => uint256) userBalances;
    ///
    mapping(address => uint256) userWithdrawRequests;
    ///
    mapping(address => uint256) userWithdrawRequestTime;

    ///
    event SetWithdrawDelay(uint256 oldWithdrawDelay, uint256 newWithdrawDelay);
    ///
    event NewDeployer(address oldDeployer, address newDeployer);
    ///
    event SignalSetDeployer(address newDeployer);
    ///
    event Deposit(address depositor, uint256 amount);
    ///
    event ClaimTokenSet(address user, bool claimInETH);
    ///
    event CancelDeployerTransfer();
    event RequestWithdraw(address withdrawer, uint256 amount);

    modifier onlyDeployer() {
        require(msg.sender == deployer, "onlyDeployer");
        _;
    }

    function totalAssets() public view override returns (uint256) {
        return _totalAssets;
    }

    /**
     */
    constructor(
        address _myc,
        address _deployer,
        uint256 _withdrawDelay
    ) ERC4626(ERC20(_myc), "LentMYC", "lentMYC") {
        deployer = _deployer;
        withdrawDelay = _withdrawDelay;
        emit NewDeployer(address(0), _deployer);
        emit SetWithdrawDelay(0, _withdrawDelay);
    }

    modifier updateUser() {
        // What do we need to do if we are in the 2 hour window here?
        uint256 latestDepositCycle = latestPendingDeposit[msg.sender]; // save an SLOAD when user doesn't deposit multiple times within one cycle. Not actually sure what ends up happening more often.
        if (latestDepositCycle < cycle) {
            // User's last deposit happened in a previous cycle, so we should update.
            CycleInfo info = cycleSharesAndAssets[latestDepositCycle];
            // Calculate the amount of shares to withdraw.
            uint256 shares = _convertToShares(
                userPendingDeposits[msg.sender], // This value is in asset.
                info._totalAssets,
                info._totalSupply
            );
            // These tokens have already been minted at the start of the cycle before which msg.sender deposited.
            // That is to say, after the
            transfer(msg.sender, shares);
        }

        uint256 latestWithdrawalCycle = latestPendingWithdrawal[msg.sender]; // save an SLOAD when user doesn't deposit multiple times within one cycle. Not actually sure what ends up happening more often.
        if (latestWithdrawalCycle < cycle) {
            // User's last withdrawal happened in a previous cycle, so we should update.
            CycleInfo info = cycleSharesAndAssets[latestDepositCycle];
            uint256 withdrawShares = userPendingWithdrawals[msg.sender];
            // Calculate the amount of assets to withdraw.
            uint256 assets = _convertToAssets(
                withdrawShares, // This value is in shares.
                info._totalAssets,
                info._totalSupply
            );
            asset.safeTransfer(msg.sender, assets);
        }
        _;
    }

    function _convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalSupply
    ) public view virtual returns (uint256) {
        return
            _totalSupply == 0
                ? _assets
                : _assets.mulDivDown(_totalSupply, _totalAssets);
    }

    function _convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalSupply
    ) public view virtual returns (uint256) {
        return
            _totalSupply == 0
                ? _shares
                : _shares.mulDivDown(_totalAssets, _totalSupply);
    }

    function deposit(uint256 assets, address) external override updateUser {
        // TODO check if we are inside 2 hour window.
        if (block.timestamp > cycleStartTime + cycleLength - preCycleTimelock) {
            // We are inside the 2 hour window: after users can deposit for next cycle, but before next cycle has started.
            revert("2 hour window deposits/redeems not yet implemented");
        }
        latestPendingDeposit[msg.sender] = cycle;
        pendingDeposits += _mycAmount;
        userPendingDeposits[msg.sender] += _mycAmount;
        asset.transferFrom(msg.sender, address(this), _mycAmount);
    }

    function redeem(
        uint256 shares,
        address,
        address
    ) external override updateUser {
        if (block.timestamp > cycleStartTime + cycleLength - preCycleTimelock) {
            // We are inside the 2 hour window: after users can deposit for next cycle, but before next cycle has started.
            revert("2 hour window deposits/redeems not yet implemented");
        }
        latestPendingWithdrawal[msg.sender] = cycle;
        pendingWithdrawals += _shareAmount;
        userPendingWithdrawals[msg.sender] += _shareAmount;
        _burn(msg.sender, withdrawShares);
    }

    /// @custom:invariant At end of any newCycle call, `totalSupply` AND `cycleSharesAndAssets[cycle]._totalSupply` should equal `x + y - z`,
    ///                   where
    ///                       x = totalSupply at the start of the previous cycle.
    ///                       y = the total amount of shares minted since the start of previous cycle - preCycleTimelock,
    ///                           at the price `totalSupply / totalAssets` as of after the previous cycle's new rewards have been added, and all redeems have been processed.
    ///                       z = the total amount of shares burnt since the start of the previous cycle - preCycleTimelock.

    /// @custom:invariant At the end of any newCycle call, `totalAssets` AND `cycleSharesAndAssets[cycle]._totalAssets` should equal `a + b + c - d`,
    ///                   where
    ///                       a = totalAssets at the start of the previous cycle.
    ///                       b = the total amount of $MYC deposited since the start of the previous cycle - preCycleTimelock.
    ///                       c = the total amount of yield generated the previous cycle, in $MYC token.
    ///                       d = the total amount of assets withdrawn since the start of the previous cycle - preCycleTimelock, at the price

    // TODO currently, the "cycle" starts before the Tokemak cycle starts. Account for this, or mention in documentation.
    function newCycle(uint256 _mycGeneratedLastCycle) external onlyGov {
        require(
            block.timestamp > cycleStartTime + cycleLength - preCycleTimelock,
            "Starting cycle too early"
        );
        cycle += 1;
        cycleStartTime = block.timestamp;
        // pendingWithdrawals have already decreased their part of the supply (burning happens at withdraw time).
        totalAssets +=
            pendingDeposits +
            _mycGeneratedLastCycle -
            previewRedeem(pendingWithdrawals); // pendingWithdrawals is in shares. Convert to assets.
        // Mint at the new price
        _mint(previewDeposit(pendingDeposits));
        // Roll over the pending deposits and redeems that were made
        pendingWithdrawals = nextPendingWithdrawals;
        pendingDeposits = nextPendingDeposits;
        // TODO account for last week's rewards.
        cycleSharesAndAssets[cycle] = CycleInfo({
            _totalSupply: totalSupply,
            _totalAssets: tempTotalAssets
        });
        asset.safeTransferFrom(msg.sender, _mycGeneratedLastCycle);
    }

    // TODO add emergency withdraw function

    /** */
    /*
    function deposit(uint256 _amount) external {
        _deposit(_amount);
    }
    */

    /** */
    /*
    function depositAndSetClaimToken(uint256 _amount, bool _claimInETH)
        external
    {
        _deposit(_amount);
        userClaimInETH[msg.sender] = _claimInETH;
        emit ClaimTokenSet(msg.sender, _claimInETH);
    }
    */

    /** */
    /*
    function _deposit(uint256 _amount) private {
        userBalances[msg.sender] += _amount;
        SafeERC20.safeTransferFrom(MYC, msg.sender, address(this), _amount);
        emit Deposit(msg.sender, _amount);
    }
    */

    function requestWithdraw(uint256 _amount) external {
        userBalances[msg.sender] -= _amount;
        userWithdrawRequests[msg.sender] += _amount;
        userWithdrawRequestTime[msg.sender] = block.timestamp;
        emit RequestWithdraw(msg.sender, _amount);
    }

    /*
    function withdraw() external {
        require(
            userWithdrawRequestTime[msg.sender] > 0,
            "Must request withdrawal"
        ); // todo should we cache userWithdrawRequestTime in memory? Compare gas
        require(
            block.timestamp >
                userWithdrawRequestTime[msg.sender] + withdrawDelay,
            "Not enough time passed"
        );

        uint256 amount = userWithdrawRequests[msg.sender];
        userWithdrawRequests[msg.sender] = 0;
        userWithdrawRequestTime[msg.sender] = 0;
        SafeERC20.safeTransfer(MYC, msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }
    */

    function afterDeposit(uint256 assets, uint256 shares)
        internal
        virtual
        override
    {}

    function beforeWithdraw(
        uint256 assets,
        uint256 /*shares*/
    ) internal override {
        require(
            userWithdrawRequestTime[msg.sender] > 0,
            "Must request withdrawal"
        ); // todo should we cache userWithdrawRequestTime in memory? Compare gas.
        require(
            block.timestamp >
                userWithdrawRequestTime[msg.sender] + withdrawDelay,
            "Not enough time passed"
        );
        require(
            userWithdrawRequests[msg.sender] == assets,
            "User must provide requested amount"
        );

        // Add `tokensPerInterval * (block.timestamp - lastUpdatedTime)` to `totalAssets`.
        _totalAssets = getTotalAssets();
        lastUpdatedTime = block.timestamp;
    }

    /**
     * @notice
     */
    function getTotalAssets() public view returns (uint256) {
        return
            _totalAssets + // Current total assets
            tokensPerSecond * // Tokens per second
            (block.timestamp - lastUpdatedTime); // Number of seconds
    }

    /** */
    function setWithdrawDelay(uint256 _withdrawDelay) external onlyDeployer {
        emit SetWithdrawDelay(withdrawDelay, _withdrawDelay);
        withdrawDelay = _withdrawDelay;
    }

    /** */
    function signalSetDeployer(address _deployer) external onlyDeployer {
        pendingNewDeployer = _deployer;
        emit SignalSetDeployer(_deployer);
    }

    /** */
    function claimDeployer() external {
        require(
            msg.sender == pendingNewDeployer,
            "msg.sender != pendingNewDeployer"
        );
        emit NewDeployer(deployer, msg.sender);
        deployer = pendingNewDeployer;
        pendingNewDeployer = address(0);
    }

    /** */
    function cancelDeployerTransfer() external onlyDeployer {
        emit CancelDeployerTransfer();
        pendingNewDeployer = address(0);
    }
}
