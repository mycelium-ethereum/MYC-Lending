# MYC-Lending

### Migration Process

1. `LentMyc.setPaused` (https://arbiscan.io/address/0x9B225FF56C48671d4D04786De068Ed8b88b672d6).
    - Note that this is just a safety precaution.
2. Start a new cycle.
3. Deploy `LentMycWithMigration`.
4. Call `LentMycWithMigration.initialize` with args `address(0), address(0), 0, 0, 0, 0, address(0)`.
5. Deploy `RewardTracker`.
6. Call `RewardTracker.initialize` (Args: `address(0), "", "", [], address(0)`).
7. Deploy `RewardDistributor`.
8. Call `RewardDistributor.initialize` (Args: `address(0), address(0), address(0)`)
9. Deploy `ERC1967` (Constructor args: `address(rewardTracker)`, `""`)
10. Deploy `ERC1967` (Constructor args: `address(rewardDistributor)`, `""`)
11. Call `initialize` on each of these with the following arguments:
    - `RewardTracker`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, "Staked MYC", "sMYC", [MYC, esMYC], address(rewardDistributorProxy)`
    - `RewardDistributor`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, 0x82af49447d8a07e3bd95bd0d56f35241523fbab1", address(rewardTrackerProxy)`
12. Upgrade `LentMyc` to `LentMycWithMigration`.
13. Verify that all variables are correctly set.
14. Verify
    - RewardDistributor.
    - RewardTracker.
    - LentMycWithMigration (and new proxy).
    - RewardTracker proxy.
    - RewardDistributor proxy.
15. Call `LentMycWithMigration.setDepositWithdrawPaused(true)`.
16. Call `LentMycWithMigration.setV2RewardTrackerAndMigrator(address(rewardTrackerProxy), address(permissionedMigrator))`.
17. Migrate accounts.