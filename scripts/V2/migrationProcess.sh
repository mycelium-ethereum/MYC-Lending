# See README.md for migration process.

forge build

zeroAddress="0x0000000000000000000000000000000000000000"
lentMycV1="0x9B225FF56C48671d4D04786De068Ed8b88b672d6"

# BEFORE RUNNING MIGRATION PROCESS:
#   - Ensure that LentMyc.paused == true.
#   - Ensure that LentMyc.setInPausedTransferMode == true.
#   - Ensure a new cycle has recently been started.

# 3. Deploy LentMycWithMigration
lentMycWithMigrationOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/LentMycWithMigration.sol:LentMycWithMigration)
arr=($lentMycWithMigrationOutput)
lentMycWithMigration=${arr[9]}
echo "Deployed LentMycWithMigration to address ${lentMycWithMigration}"

# 4. Call `LentMycWithMigration.initialize` with args `address(0), address(0), 0, 0, 0, 0, address(0)`.
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $lentMycWithMigration \
    "initialize(address,address,uint256,uint256,uint256,address)" \
    $zeroAddress $zeroAddress "0" "0" "0" "0" $zeroAddress

# 5. Deploy `RewardTracker`.
rewardTrackerOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/RewardTracker.sol:RewardTracker)
arr=($rewardTrackerOutput)
rewardTracker=${arr[9]}
echo "Deployed RewardTracker to address ${rewardTracker}"

# 6. Call `RewardTracker.initialize` (Args: `address(0), "", "", [], address(0)`).
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTracker \
    "initialize(address,string,string,address[],address)" \
    $zeroAddress "" "" "[]" $zeroAddress

# 7. Deploy `RewardDistributor`.
rewardDistributorOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/RewardDistributor.sol:RewardDistributor)
arr=($rewardDistributorOutput)
rewardDistributor=${arr[9]}
echo "Deployed RewardDistributor to address ${rewardDistributor}"

# 8. Call `RewardDistributor.initialize` (Args: `address(0), address(0), address(0)`)
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardDistributor \
    "initialize(address,address,address)" \
    $zeroAddress $zeroAddress $zeroAddress

echo "Pause here, ensure rewardDistributor.isInitialized == true, rewardTracker.isInitialized == true, and lentMycWithMigration.initialize is reverting."
echo "Then comment out these lines and re-run"
exit 1

# 9. Deploy `ERC1967` (Constructor args: `address(rewardTracker)`, `""`)
echo "Deploying first proxy"
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $rewardTracker "" \
    --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy)
echo "Deployed proxy"
echo $proxy
proxyArr=($proxy)
echo "Deployed proxy"
rewardTrackerProxy=${proxyArr[9]}

# 10. Deploy `ERC1967` (Constructor args: `address(rewardDistributor)`, `""`)
echo "Deploying second proxy"
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $rewardDistributor "" \
    --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy)
echo "Deployed proxy"
echo $proxy
proxyArr=($proxy)
echo "Deployed proxy"
rewardDistributorProxy=${proxyArr[9]}

# 11. Call `initialize` on each of these with the following arguments:
#     - `RewardTracker`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, "Staked MYC", "sMYC", [MYC, esMYC], address(rewardDistributorProxy)`
#     - `RewardDistributor`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, 0x82af49447d8a07e3bd95bd0d56f35241523fbab1", address(rewardTrackerProxy)`
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTrackerProxy \
    "initialize(address,string,string,address[],address)" \
    $gov "Staked MYC" "sMYC" "[${MYC},${esMYC}]" $rewardDistributorProxy
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardDistributorProxy \
    "initialize(address,address,address)" \
    $gov $WETH $rewardTrackerProxy

echo "Pause here, ensure rewardDistributorProxy.isInitialized == true, and rewardTrackerProxy.isInitialized == true"
echo "Then check all variables were set correctly."
echo "Then comment out these lines and re-run."
exit 1

# 12. Upgrade `LentMyc` to `LentMycWithMigration`.
        # lProxy.upgradeTo(address(dummyUpgrade));
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $lentMycV1 \
    "upgradeTo(address)" \
    $lentMycWithMigration

# 13. Verify that all variables are correctly set.
# 14. Verify on etherscan:
    # - RewardDistributor.
    # - RewardTracker.
    # - LentMycWithMigration (and new proxy).
    # - RewardTracker proxy.
    # - RewardDistributor proxy.
echo "Pause here, ensure lentMyc variables are all set correctly"
echo "Then Verify all contracts on Etherscan."
echo "15. Call `LentMycWithMigration.setDepositWithdrawPaused(true)`."
echo "16. Call `LentMycWithMigration.setInPausedTransferMode(true)`."
echo "17. Call `LentMycWithMigration.setV2RewardTrackerAndMigrator(address(rewardTrackerProxy), address(permissionedMigrator))`."
echo "18. Call `RewardTracker.setHandler(address(lentMycWithMigration), true);`."
echo "19. Migrate accounts."