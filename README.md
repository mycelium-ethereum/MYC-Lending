# MYC-Lending

### Migration Process

1. `LentMyc.setPaused` (https://arbiscan.io/address/0x9B225FF56C48671d4D04786De068Ed8b88b672d6).
    - Note that this is just a safety precaution.
1. Start a new cycle.
1. Deploy `LentMycWithMigration`.
1. Call `LentMycWithMigration.initialize` with args `address(0), address(0), 0, 0, 0, 0, address(0)`.
1. Deploy `RewardTracker`.
1. Call `RewardTracker.initialize` (Args: `address(0), "", "", [], address(0)`).
1. Deploy `RewardDistributor`.
1. Call `RewardDistributor.initialize` (Args: `address(0), address(0), address(0)`)
1. Deploy `ERC1967` (Constructor args: `address(rewardTracker)`, `""`)
1. Deploy `ERC1967` (Constructor args: `address(rewardDistributor)`, `""`)
1. Call `initialize` on each of these with the following arguments:
    - `RewardTracker`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, "Staked MYC", "sMYC", [MYC, esMYC], address(rewardDistributorProxy)`
    - `RewardDistributor`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, 0x82af49447d8a07e3bd95bd0d56f35241523fbab1, address(rewardTrackerProxy)`
1. Upgrade `LentMyc` to `LentMycWithMigration`.
1. Call `LentMycWithMigration.setInPausedTransferMode(true)`.
1. Verify that all variables are correctly set.
1. Verify
    - RewardDistributor.
    - RewardTracker.
    - LentMycWithMigration (and new proxy).
    - RewardTracker proxy.
    - RewardDistributor proxy.
1. Call `LentMycWithMigration.setDepositWithdrawPaused(true)`.
1. Call `LentMycWithMigration.setV2RewardTrackerAndMigrator(address(rewardTrackerProxy), address(permissionedMigrator))`.
1. Call `RewardTracker.setHandler(address(lentMycWithMigrationProxy), true);`.
1. Call `RewardTracker.setInPrivateTransferMode(true);`.
1. Migrate accounts.
1. If everything looks good, unpause LentMyc to allow people to claim and update balance (i.e. get MYC they they may have requested withdraw).

TODO add test for lentMyc.transfer -> newCycle -> upgrade -> migrate