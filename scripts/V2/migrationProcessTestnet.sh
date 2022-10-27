
# See README.md for migration process.

zeroAddress="0x0000000000000000000000000000000000000000"
LBLUE='\033[1;36m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

forge build

echo ""
echo "Pausing LMYC"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $LMYC \
    "setPaused(bool)" \
    "true")

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
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $lentMycWithMigration \
    "initialize(address,address,uint256,uint256,uint256,uint256,address)" \
    $zeroAddress $zeroAddress "0" "0" "0" "0" $zeroAddress)

# 5. Deploy `RewardTracker`.
rewardTrackerOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/RewardTracker.sol:RewardTracker)
arr=($rewardTrackerOutput)
rewardTracker=${arr[9]}
echo ""
echo "Deployed RewardTracker to address ${rewardTracker}"

echo ""
echo "Initializing RewardTracker with "
echo $zeroAddress "\"\"" "\"\"" "[]" $zeroAddress
# 6. Call `RewardTracker.initialize` (Args: `address(0), "", "", [], address(0)`).
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTracker \
    "initialize(address,string,string,address[],address)" \
    $zeroAddress "" "" "[]" $zeroAddress)

# 7. Deploy `RewardDistributor`.
echo ""
echo "Deploying RewardDistributor"
rewardDistributorOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/RewardDistributor.sol:RewardDistributor)
arr=($rewardDistributorOutput)
rewardDistributor=${arr[9]}
echo ""
echo "Deployed RewardDistributor to address ${rewardDistributor}"

# 8. Call `RewardDistributor.initialize` (Args: `address(0), address(0), address(0)`)
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardDistributor \
    "initialize(address,address,address)" \
    $zeroAddress $zeroAddress $zeroAddress)

echo ""
echo -e "${LBLUE}--- NEXT STEPS ---${NC}"
echo "Ensure rewardDistributor.isInitialized == true, rewardTracker.isInitialized == true, and lentMycWithMigration.initialize is reverting."
sleep 3s

# 9. Deploy `ERC1967` (Constructor args: `address(rewardTracker)`, `""`)
echo "Deploying rewardTracker proxy"
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $rewardTracker "" \
    --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy)
proxyArr=($proxy)
rewardTrackerProxy=${proxyArr[9]}
echo "Deployed proxy"
echo $rewardTrackerProxy
echo ""

# 10. Deploy `ERC1967` (Constructor args: `address(rewardDistributor)`, `""`)
echo "Deploying rewardDistributor proxy"
echo ""
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $rewardDistributor "" \
    --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy)
proxyArr=($proxy)
rewardDistributorProxy=${proxyArr[9]}
echo "Deployed proxy"
echo $rewardDistributorProxy
echo ""

# 11. Call `initialize` on each of these with the following arguments:
#     - `RewardTracker`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, "Staked MYC", "sMYC", [MYC, esMYC], address(rewardDistributorProxy)`
#     - `RewardDistributor`: `0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac, 0x82af49447d8a07e3bd95bd0d56f35241523fbab1", address(rewardTrackerProxy)`
echo "Initializing RewardDistributor"
echo $ACCOUNT "Staked MYC" "sMYC" "[${MYC},${esMYC}]" $rewardDistributorProxy
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTrackerProxy \
    "initialize(address,string,string,address[],address)" \
    $ACCOUNT "Staked MYC" "sMYC" "[${MYC},${esMYC}]" $rewardDistributorProxy)
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardDistributorProxy \
    "initialize(address,address,address)" \
    $ACCOUNT $WETH $rewardTrackerProxy)

echo ""
echo -e "${LBLUE}--- NEXT STEPS ---${NC}"
echo "Ensure rewardDistributorProxy.isInitialized == true, and rewardTrackerProxy.isInitialized == true"
echo "Then check all variables were set correctly."
sleep 3s

echo ""
echo -e "${GREEN}Upgrading proxy...${NC}"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $LMYC \
    "upgradeTo(address)" \
    $lentMycWithMigration)

echo ""
echo -e "${GREEN}Pausing deposits and withdrawals...${NC}"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $LMYC \
    "setDepositWithdrawPaused(bool)" \
    "true")

echo ""
echo -e "${GREEN}Pausing transfer mode...${NC}"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $LMYC \
    "setInPausedTransferMode(bool)" \
    "true")

echo ""
echo -e "${GREEN}Setting V2 RewardTracker and Migrator...${NC}"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $LMYC \
    "setV2RewardTrackerAndMigrator(address,address)" \
    $rewardTrackerProxy $ACCOUNT)

echo ""
echo -e "${GREEN}Setting RewardTracker handler...${NC}"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTrackerProxy \
    "setHandler(address,bool)" \
    $LMYC "true")

echo ""
echo -e "${GREEN}Setting RewardTracker inPrivateTransferMode...${NC}"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTrackerProxy \
    "setInPrivateTransferMode(bool)" \
    "true")


echo ""
echo -e "${GREEN}Setting \`RewardTracker.depositCap\`${NC}"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTrackerProxy \
    "setDepositCap(uint256)" \
    "100000000000000000000000000")

echo ""
echo "Unpausing LMYC"
echo ""
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $LMYC \
    "setPaused(bool)" \
    "false")

echo "export REWARD_TRACKER_PROXY=${rewardTrackerProxy} ; \\"
echo "export REWARD_DISTRIBUTOR_PROXY=${rewardDistributorProxy} ;\\"
echo "export REWARD_TRACKER_IMPL=${rewardTracker} ;\\"
echo "export REWARD_DISTRIBUTOR_IMPL=${rewardDistributor}"