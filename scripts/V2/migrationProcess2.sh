# See README.md for migration process.

NC='\033[0m' # No Color
LBLUE='\033[1;36m'
forge build
WETH="0x82af49447d8a07e3bd95bd0d56f35241523fbab1"
gov="0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac"
MYC="0xc74fe4c715510ec2f8c61d70d397b32043f55abe"
esMYC="0x7CEC785fba5ee648B48FBffc378d74C8671BB3cb"

# 9. Deploy `ERC1967` (Constructor args: `address(rewardTracker)`, `""`)
echo "Deploying first proxy"
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $REWARD_TRACKER_IMPL "" \
    --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy)
proxyArr=($proxy)
rewardTrackerProxy=${proxyArr[9]}
echo "Deployed RewardTracker proxy"
echo $proxy

# 10. Deploy `ERC1967` (Constructor args: `address(rewardDistributor)`, `""`)
echo "Deploying second proxy"
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $REWARD_DISTRIBUTOR_IMPL "" \
    --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy)
proxyArr=($proxy)
rewardDistributorProxy=${proxyArr[9]}
echo "Deployed RewardDistributor proxy"
echo $proxy

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

echo ""
echo -e "${LBLUE}--- NEXT STEPS ---${NC}"
echo "Ensure rewardDistributorProxy.isInitialized == true, and rewardTrackerProxy.isInitialized == true"
echo "Then check all variables were set correctly."
echo "Then run \`export REWARD_DISTRIBUTOR_PROXY=\"${rewardDistributorProxy}\" && export REWARD_TRACKER_PROXY=\"${rewardTrackerProxy}\"\`"
echo "Then run \`./scripts/migrationProcess3.sh\`"