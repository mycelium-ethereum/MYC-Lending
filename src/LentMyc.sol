// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

import "forge-std/console.sol";

contract LentMyc is ERC20 {
    /// @custom:invariant `trueBalanceOf(user)` always equals what `balanceOf` equals immediately after a call to `updateUser(user)`.

    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    struct CycleInfo {
        uint256 _totalSupply;
        uint256 _totalAssets;
    }

    /// @notice A permissioned address to change parameters, and start new cycle/set rewards.
    address public gov;
    /// @notice Governance transfer happens in two steps.
    address public pendingNewGov;
    uint256 public amountDeployed;
    uint256 public totalWithdrawAmountRequested;
    // Amount of time each cycle lasts for.
    uint256 public cycleLength;
    // The zero-indexed count of cycle.
    uint256 public cycle = 1;
    // The time at which the current cycle started.
    uint256 public cycleStartTime;
    /// @notice The amount of time before the cycle starts before which, users must deposit to be included in next week's rewards.
    /// @notice Once this timelock window has started, deposits and redeem requests will be locked.
    uint256 public preCycleTimelock;

    /// @notice Amount of $MYC pending to be deposited by users.
    mapping(address => uint256) public userPendingDeposits;
    ///
    mapping(address => uint256) public userPendingRedeems;
    ///
    mapping(address => uint256) public latestPendingDeposit;
    ///
    mapping(address => uint256) public latestPendingRedeem;
    ///
    mapping(uint256 => CycleInfo) public cycleSharesAndAssets;

    mapping(address => uint256) public userCumulativeEthRewards;
    mapping(address => uint256) public userEthRewardsClaimed;
    mapping(address => uint256) public userLastUpdated;

    mapping(uint256 => uint256) public cycleCumulativeEthRewards;

    /// TODO pendingDeposits

    uint256 public totalAssets;

    uint256 public pendingDeposits;
    uint256 public pendingRedeems;

    uint256 public lastUpdatedTime;

    uint256 public dust;

    /// @notice Limit on the amount of $MYC that can be deposited
    uint256 public depositCap;

    // TODO add upgradeable contract for compounding/dex swapping

    /// @notice If true, denominate a user's rewards in ETH. If false, denominate in MYC.
    /// @dev Every address defaults to 0 (false).
    /// TODO use
    mapping(address => bool) public userClaimInETH;

    ///
    event SetDepositCap(uint256 depositCap, uint256 newDepositCap);
    ///
    event Claimed(address claimant, uint256 ethRewards);
    ///
    event SetPreCycleTimelock(
        uint256 oldPreCycleTimelock,
        uint256 preCycleTimelock
    );
    ///
    event StartCycle(uint256 cycleStartTime);
    ///
    event SetCycleLength(uint256 oldCycleLength, uint256 newCycleLength);
    ///
    event NewGov(address oldGov, address newGov);
    ///
    event SignalSetGov(address newGov);
    ///
    event Deposit(address depositor, uint256 amount);
    ///
    event ClaimTokenSet(address user, bool claimInETH);
    ///
    event CancelGovTransfer();
    event RequestWithdraw(address withdrawer, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed caller,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC20 public immutable asset;
    modifier onlyGov() {
        require(msg.sender == gov, "onlyGov");
        _;
    }

    /**
     */
    constructor(
        address _myc,
        address _gov,
        uint8 _decimals,
        uint256 _cycleLength,
        uint256 _firstCycleStart,
        uint256 _preCycleTimelock,
        uint256 _depositCap
    ) ERC20("lentMYC", "lMYC", _decimals) {
        asset = ERC20(_myc);
        require(asset.decimals() == _decimals, "Mismatching decimals");
        gov = _gov;
        cycleLength = _cycleLength;
        cycleStartTime = _firstCycleStart;
        preCycleTimelock = _preCycleTimelock;
        depositCap = _depositCap;
        emit NewGov(address(0), _gov);
        emit SetCycleLength(0, _cycleLength);
        emit StartCycle(_firstCycleStart);
        emit SetPreCycleTimelock(0, _preCycleTimelock);
        emit SetDepositCap(0, _depositCap);
    }

    // TODO cancel deposit/withdrawal request. Make sure can't do during 2 hour window
    // TODO go through all functions and ensure correct permissions.

    /**
     * @notice Sets the amount of MYC that can be deposited into the contract.
     */
    function setDepositCap(uint256 newDepositCap) external onlyGov {
        emit SetDepositCap(depositCap, newDepositCap);
        depositCap = newDepositCap;
    }

    /**
     * @notice Sets the cycleLength (approximate number of seconds each cycle lasts for).
     * @param newCycleLength The new cycleLength value.
     * @dev Requires `newCycleLength > 0`.
     */
    function setCycleLength(uint256 newCycleLength) external onlyGov {
        require(newCycleLength > 0, "cycleLength == 0");
        emit SetCycleLength(cycleLength, newCycleLength);
        cycleLength = newCycleLength;
    }

    /**
     * @notice Sets the preCycleTimelock (number of seconds before cycleStartTime + cycleLength for which deposit and redeem requests are blocked).
     * @param newPreCycleTimelock The new preCycleTimelock value.
     */
    function setPreCycleTimelock(uint256 newPreCycleTimelock) external onlyGov {
        emit SetPreCycleTimelock(preCycleTimelock, newPreCycleTimelock);
        preCycleTimelock = newPreCycleTimelock;
    }

    /**
     * @notice Initiates a transfer of contract governance.
     * @param _gov The new pending gov address.
     * @dev After `signalSetGov` is called, `claimGov` can be called by `_gov` to claim the `gov` role.
     */
    function signalSetGov(address _gov) external onlyGov {
        pendingNewGov = _gov;
        emit SignalSetGov(_gov);
    }

    /**
     * @notice Claims `pendingNewGov` as the new `gov` address.
     * @dev `signalSetGov` sets `pendingNewGov`. `claimGov` sets `gov` as `pendingNewGov`.
     * @dev Requires `msg.sender == pendingNewGov`.
     */
    function claimGov() external {
        require(msg.sender == pendingNewGov, "msg.sender != pendingNewGov");
        emit NewGov(gov, msg.sender);
        gov = pendingNewGov;
        pendingNewGov = address(0);
    }

    /**
     * @notice Cancels any pending gov transfer initiated by `signalSetGov`.
     */
    function cancelGovTransfer() external onlyGov {
        pendingNewGov = address(0);
        emit CancelGovTransfer();
    }

    // TODO redeems aren't automatically sent out. Front-end needs a way to "claim" redeems (which would, in reality, just be calling updateUser).
    /**
     * @notice Updates a users lentMYC, MYC balances, and ETH rewards.
     * @dev Transfers any lentMYC or MYC owing to `user`.
     * @dev Does not transfer ETH rewards. This has to be done by calling `claim`.
     */
    function updateUser(address user) public {
        (uint256 shareTransfer, uint256 assetTransfer) = _updateUser(user);
        if (shareTransfer > 0) {
            delete latestPendingDeposit[user];
            delete userPendingDeposits[user];
            selfTransfer(user, shareTransfer);
        }
        if (assetTransfer > 0) {
            delete latestPendingRedeem[user];
            delete userPendingRedeems[user];
            asset.safeTransfer(user, assetTransfer);
        }

        // Get ETH rewards since last update
        uint256 newUserEthRewards = _updatedEthRewards(user);
        userLastUpdated[user] = cycle;
        userCumulativeEthRewards[user] += newUserEthRewards;
    }

    /**
     * @notice Claim all outstanding ETH rewards.
     * @dev Taken as the difference between user's cumulative ETH rewards, and their claimed ETH rewards.
     */
    function claim() external {
        // TODO gas cost savings of storing userEthRewardsClaimed in mem
        updateUser(msg.sender);
        uint256 claimed = userEthRewardsClaimed[msg.sender]; // Save SLOAD
        uint256 cumulative = userCumulativeEthRewards[msg.sender]; // Save SLOAD
        uint256 ethRewards = cumulative - claimed;
        userEthRewardsClaimed[msg.sender] = cumulative;
        Address.sendValue(payable(msg.sender), ethRewards);
        emit Claimed(msg.sender, ethRewards);
    }

    /// @custom:invariant After updateUser is called, there should be no deposits or withdrawals that were made in a cycle prior to the current one. i.e. they should be deleted.
    /// @custom:invariant After updateUser is called, the user should have their shares balance increased by `deposit_asset_amount * total_share_supply / total_assets`, or by `deposit_asset_amount` if `total_share_supply = 0`.
    ///                   where `deposit_asset_amount` is the amount of $MYC they have deposited in a previous cycle.

    /**
     * @notice
     */
    function deposit(uint256 assets, address receiver) external {
        // We have a `receiver` parameter, but this is just to be semi-compliant to ERC4626.
        require(msg.sender == receiver, "msg.sender != receiver");
        require(assets > 0, "assets == 0");
        // We are inside the 2 hour window: after users can deposit for next cycle, but before next cycle has started.
        require(
            block.timestamp < cycleStartTime + cycleLength - preCycleTimelock,
            "Deposit requests locked"
        );
        require(
            asset.balanceOf(address(this)) + assets <= depositCap,
            "Deposit cap exceeded"
        );
        updateUser(receiver);
        latestPendingDeposit[receiver] = cycle;
        pendingDeposits += assets;
        userPendingDeposits[receiver] += assets;
        asset.transferFrom(receiver, address(this), assets);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external {
        // We want to be compliant with ERC4626, but only want msg.sender to be able to control their own assets.
        require(receiver == msg.sender, "receiver != msg.sender");
        require(owner == msg.sender, "owner != msg.sender");
        updateUser(msg.sender);
        if (block.timestamp > cycleStartTime + cycleLength - preCycleTimelock) {
            // We are inside the 2 hour window: after users can deposit for next cycle, but before next cycle has started.
            revert("Redeem requests locked");
        }
        latestPendingRedeem[msg.sender] = cycle;
        pendingRedeems += shares;
        userPendingRedeems[msg.sender] += shares;
        _burn(msg.sender, shares);
    }

    /// @custom:invariant At end of any newCycle call, `totalSupply` AND `cycleSharesAndAssets[cycle]._totalSupply` should equal `x + y - z`,
    ///                   where
    ///                       x = totalSupply at the start of the previous cycle.
    ///                       y = the total amount of shares minted since the start of previous cycle,
    ///                           at the price `totalSupply / totalAssets`,
    ///                           as of after the previous cycle's new rewards have been added,
    ///                           and the totalSupply has been changed to reflect burning from redeems.
    ///                           Or a price of 1, if `totalAssets = 0`,
    ///                       z = the total amount of shares burnt since the start of the previous cycle.

    /// @custom:invariant At the end of any newCycle call, `totalAssets` AND `cycleSharesAndAssets[cycle]._totalAssets` should equal `a + b + c - d`,
    ///                   where
    ///                       a = totalAssets at the start of the previous cycle.
    ///                       b = the total amount of $MYC deposited since the start of the previous cycle.
    ///                       c = the total amount of yield generated during the previous cycle, in $MYC token.
    ///                       d = the total amount of assets withdrawn since the start of the previous cycle,
    ///                           at the price `totalAssets / totalSupply`, after the previous cycle's new rewards have been added,
    ///                           and the totalAssets has been changed to reflect new assets deposited during the cycle.
    ///                           Or a price of 1, if `totalAssets = 0`,

    // TODO currently, the "cycle" starts before the Tokemak cycle starts. Account for this, or mention in documentation.
    // TODO what happens if there are losses and there isn't enough MYC after pendingDeposits - mycLostLastCycle - redemptionAssets?

    /**
     * @notice Starts a new cycle. This involves updating totalAssets based on any MYC lost during cycle, withdrawing more MYC for this new cycle,
     *         updating ETH rewards, minting new shares from last cycles deposits.
     * @param mycLostLastCycle If there was a loss in a given cycle, this is denominated in MYC.
     * @param amountToWithdraw Amount of MYC to withdraw from contract to deploy in new cycle.
     * @dev The *exact* amount given as parameter `amountToWithdraw` is *always* transferred to `gov`. If we do not have enough balance,
     *      the call will fail.
     * @dev Ensures enough $MYC balance in contract to pay out all pending redeems.
     * @dev Any losses incurred has to be denominated in MYC because we can't require users "pay back" their ETH rewards.
     */
    function newCycle(uint256 mycLostLastCycle, uint256 amountToWithdraw)
        external
        payable
        onlyGov
    {
        require(
            block.timestamp > cycleStartTime + cycleLength - preCycleTimelock,
            "Starting cycle too early"
        );
        cycleStartTime = block.timestamp;

        // ETH per share
        if (totalSupply == 0) {
            // Nobody has minted yet, that means this is most likely the first cycle.
            // Either way, we want to just add all msg.value to dust.
            // Note that this is an extreme edge case.

            // TODO write a test where totalSuypply = 0, but rewards a high -> shoudl transfer over to next cycle
            cycleCumulativeEthRewards[cycle] = 0;
            dust = msg.value;
        } else {
            uint256 ethPerShare = (msg.value + dust).divWadDown(totalSupply);
            cycleCumulativeEthRewards[cycle] =
                cycleCumulativeEthRewards[cycle - 1] +
                ethPerShare;
            uint256 currentCycleCumulativeEthRewards = cycleCumulativeEthRewards[
                    cycle
                ];

            // Roll over dust
            if (address(this).balance > currentCycleCumulativeEthRewards) {
                dust = address(this).balance - currentCycleCumulativeEthRewards;
            } else {
                dust = 0;
            }
        }

        cycle += 1;

        // TODO should redemptionAssets be calculated before or after the mint. 99% sure it should be after. But then how do you calculate totalAssets? Test to figure out.
        uint256 redemptionAssets = previewRedeem(pendingRedeems);
        // Don't want last cycles losses to affect new minters
        totalAssets -= mycLostLastCycle;
        _mint(address(this), previewDeposit(pendingDeposits));
        // Total assets should not reflect deposits and redeems
        if (pendingDeposits > redemptionAssets) {
            totalAssets += pendingDeposits - redemptionAssets;
        } else if (pendingDeposits < redemptionAssets) {
            // Want to subtract (redemptionAssets - pendingDeposits)
            totalAssets -= (redemptionAssets - pendingDeposits);
        }

        pendingRedeems = 0;
        pendingDeposits = 0;
        cycleSharesAndAssets[cycle] = CycleInfo({
            _totalSupply: totalSupply,
            _totalAssets: totalAssets
        });

        asset.transfer(msg.sender, amountToWithdraw);

        // Ensure after new cycle starts, enough is in contract to pay out the pending redemptions.
        require(
            asset.balanceOf(address(this)) >= redemptionAssets,
            "MYC given is less than required"
        );
    }

    // TODO test can't start new cycle after heaps of losses

    // TODO add controlled release functionality

    function withdrawEth(uint256 amount) external onlyGov {
        require(amount <= address(this).balance);
        Address.sendValue(payable(msg.sender), amount);
    }

    function withdrawToken(address token, uint256 amount) external onlyGov {
        ERC20(token).transfer(msg.sender, amount);
    }

    // TODO add interface

    /**
     * @return The lentMYC balance of `user` after an account update.
     */
    function trueBalanceOf(address user) public view returns (uint256) {
        (uint256 shareTransfer, ) = _updateUser(user);
        return balanceOf[user] + shareTransfer;
    }

    /**
     * @dev Wrapper around `ERC20.transferFrom` which updates both `from` and `to` before receiving the transfer.
     * @dev Basically before doing any transfers, we want to make sure that the user is in an updated state.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        // TODO is it OK to only update before transferring? I'm sure it is, but should probably just make sure.
        updateUser(from);
        updateUser(to);
        return super.transferFrom(from, to, amount);
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        updateUser(msg.sender);
        updateUser(to);
        return super.transfer(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        FETCHING UPDATED STATE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the updated ETH rewards entitled to a user.
     * @param user The address to get udpated ETH rewards
     * @dev Does not update state/transfer ETH rewards.
     */
    function _updatedEthRewards(address user) private view returns (uint256) {
        // Get ETH rewards since last update
        uint256 cycleLastUpdated = userLastUpdated[user];
        if (cycleLastUpdated == 0 || cycleLastUpdated == cycle) {
            // First time, or already updated this cycle
            return 0;
        }

        uint256 lastUpdatedEthRewards = cycleCumulativeEthRewards[
            cycleLastUpdated
        ];
        uint256 currentCumulativeEthRewards = cycleCumulativeEthRewards[
            cycle - 1
        ];
        uint256 newUserEthRewards = (currentCumulativeEthRewards -
            lastUpdatedEthRewards).mulWadDown(trueBalanceOf(user));
        return newUserEthRewards;
    }

    /**
     * @notice Calculate how much ETH a given user can claim.
     * @param user The address to get claimable ETH rewards for.
     * @return An ETH value.
     */
    function getClaimableAmount(address user) external view returns (uint256) {
        uint256 newUserEthRewards = _updatedEthRewards(user);
        uint256 ethRewards = newUserEthRewards +
            userCumulativeEthRewards[user] -
            userEthRewardsClaimed[user];
        return ethRewards;
    }

    /**
     * @notice Gets the updated state of a user's lentMYC and MYC balance.
     * @return shareTransferOut Amount of shares (lentMYC) that can be given to `user`. This is the result of a past deposit.
     * @return assetTransferOut Amount of assets (MYC) that can be given to `user`. This is the result of a past redeem.
     */
    function _updateUser(address user) private view returns (uint256, uint256) {
        // DEPOSIT
        uint256 latestDepositCycle = latestPendingDeposit[user]; // save an SLOAD when user doesn't deposit multiple times within one cycle. Not actually sure what ends up happening more often.
        uint256 shareTransferOut;
        uint256 assetTransferOut;
        if (latestDepositCycle < cycle && latestDepositCycle > 0) {
            // User's last deposit happened in a previous cycle, so we should update.
            CycleInfo memory info = cycleSharesAndAssets[latestDepositCycle];
            // Calculate the amount of shares to withdraw.
            uint256 shares = convertToShares(
                userPendingDeposits[user], // This value is in asset.
                info._totalAssets,
                info._totalSupply
            );
            // We are giving the user their deposit, so now need to delete that data.
            // These tokens have already been minted at the start of the cycle before which user deposited.
            shareTransferOut = shares;
        }

        // REDEEM
        uint256 latestRedeemCycle = latestPendingRedeem[user]; // save an SLOAD when user doesn't deposit multiple times within one cycle. Not actually sure what ends up happening more often.
        if (latestRedeemCycle < cycle && latestRedeemCycle > 0) {
            // User's last redeem happened in a previous cycle, so we should update.
            CycleInfo memory info = cycleSharesAndAssets[latestRedeemCycle];
            // Calculate the amount of assets to withdraw.
            uint256 assets = convertToAssets(
                userPendingRedeems[user],
                info._totalAssets,
                info._totalSupply
            );
            // We are giving the user their redeem, so now need to delete that data.
            assetTransferOut = assets;
        }
        return (shareTransferOut, assetTransferOut);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function convertToShares(
        uint256 _assets,
        uint256 _totalAssets,
        uint256 _totalSupply
    ) public view virtual returns (uint256) {
        return
            _totalSupply == 0
                ? _assets
                : _assets.mulDivDown(_totalSupply, _totalAssets);
    }

    function convertToAssets(
        uint256 _shares,
        uint256 _totalAssets,
        uint256 _totalSupply
    ) public view virtual returns (uint256) {
        return
            _totalSupply == 0
                ? _shares
                : _shares.mulDivDown(_totalAssets, _totalSupply);
    }

    function previewDeposit(uint256 assets)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = totalSupply;
        return convertToShares(assets, totalAssets, supply);
    }

    function previewRedeem(uint256 shares)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 supply = totalSupply;
        return convertToAssets(shares, totalAssets, supply);
    }

    /**
     * @notice Transfer lentMYC *from* the lentMYC contract's ownership.
     * @param to Recipient.
     * @param amount Amount to transfer.
     */
    function selfTransfer(address to, uint256 amount) private returns (bool) {
        balanceOf[address(this)] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(this), to, amount);

        return true;
    }
}
