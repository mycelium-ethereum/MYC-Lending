# See README.md for migration process.

zeroAddress="0x0000000000000000000000000000000000000000"
LBLUE='\033[1;36m'
NC='\033[0m' # No Color
forge build

# BEFORE RUNNING MIGRATION PROCESS:
#   - Ensure that LentMyc.paused == true.
#   - Ensure a new cycle has recently been started.

# 3. Deploy LentMycWithMigration
lentMycWithMigrationOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/LentMycWithMigration.sol:LentMycWithMigration)
arr=($lentMycWithMigrationOutput)
lentMycWithMigration=${arr[9]}
echo "Deployed LentMycWithMigration to address ${lentMycWithMigration}"

# 4. Call `LentMycWithMigration.initialize` with args `address(0), address(0), 0, 0, 0, 0, address(0)`.
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $lentMycWithMigration \
    "initialize(address,address,uint256,uint256,uint256,uint256,address)" \
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

echo ""
echo -e "${LBLUE}--- NEXT STEPS ---${NC}"
echo "Ensure rewardDistributor.isInitialized == true, rewardTracker.isInitialized == true, and lentMycWithMigration.initialize is reverting."
echo "Then run \`export REWARD_DISTRIBUTOR_IMPL=\"${rewardDistributor}\" && export REWARD_TRACKER_IMPL=\"${rewardTracker}\"  && export LMYC_WITH_MIGRATION=\"${lentMycWithMigration}\" \`"
echo "Then run \`./scripts/migrationProcess2.sh\`"