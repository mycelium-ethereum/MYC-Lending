# MYC-Lending

### Test the Migration on Testnet
Set env vars

`export RPC_URL=<RPC_URL>`

`export PRIVATE_KEY=<PRIVATE_KEY>`

`export ACCOUNT=<MAIN_TESTNET_EOA>`

Deploy contracts

`./scripts/V1/deployTestnet.sh`

Run the `export` commands given at the end of the script to set the env vars.

Example: `export MYC=0xDBEb80f81e2534500841013335F2b4A57e1B3EF3 ; export esMYC=0x9E0e9A4Ad4c9a1B676EA432B15607FCb338D1CE9 ; export LMYC=0x695144da81C76337F8Aa3c5709887147744F7698 ; export WETH=0x2b434670049cA89A75946447510AEF8fAAda0EF8 ; export LMYC_V1_IMPL=0xA3884728314DdA89Cb314a9f68994570A16899a5`

Start a new cycle

`./scripts/V1/newCycle.sh # Let this script finish/exit so it reconfigures variables properly`

Deposit some MYC

`./scripts/V1/deposit.sh 1000000000000000000000`

Run a few cycles to get some rewards

`./scripts/V1/newCycle.sh && ./scripts/V1/newCycle.sh # Let this script finish/exit so it reconfigures variables properly`

Print out user's staked amount, claimable ETH, etc.

`./scripts/V1/getUserData.sh # Variables should be set`

Print out general vault info

`./scripts/V1/getCycleData.sh # Variables should be set`

Run the migration process

`./scripts/V2/migrationProcess.sh `

Run the `export` commands given at the end of the script to set the env vars.

Migrate your address

`cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "migrate(address)" $ACCOUNT`

Print out user's staked amount, claimable ETH, etc. Claimable ETH should remain unchanged

`./scripts/V1/getUserData.sh # Variables should be set`

Claim ETH on V1 rewards

`cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "claim(bool,bytes)" "false" ""`

Print out the RewardTracker MYC staked (should be your migrated amount), and your MYC staked (should equal eachother)

`./scripts/V2/getTrackerUserData.sh`

Try to migrate again (should revert)

`cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "migrate(address)" $ACCOUNT`

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
1. Call `RewardTracker.setDepositCap(100_000_000 * 1e18)`
1. Migrate accounts.
1. If everything looks good, unpause LentMyc to allow people to claim and update balance (i.e. get MYC they they may have requested withdraw).
