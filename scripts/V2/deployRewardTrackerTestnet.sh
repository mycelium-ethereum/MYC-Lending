gov="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"
admin="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"

forge build

# UNCOMMENT TO REDEPLOY

#testWethOutput=$(forge create --rpc-url $RPC_URL --constructor-args "Test Wrapped Ether" "tWETH" "18" --private-key $PRIVATE_KEY src/token/Token.sol:Token)
#arr=($testWethOutput)
#TEST_WETH=${arr[9]}
#echo "Deployed test WETH to address ${TEST_WETH}"

#mycTokenOutput=$(forge create --rpc-url $RPC_URL --constructor-args "Mycelium" "MYC" "18" --private-key $PRIVATE_KEY src/token/Token.sol:Token)
#arr=($mycTokenOutput)
#myc=${arr[9]}
#echo "Deployed test MYC to address ${myc}"

#esMycTokenOutput=$(forge create --rpc-url $RPC_URL --constructor-args "Escrowed Mycelium" "esMYC" "18" --private-key $PRIVATE_KEY src/token/Token.sol:Token)
#arr=($esMycTokenOutput)
#esMyc=${arr[9]}
#echo "Deployed test esMYC to address ${esMyc}"

export $(grep -v '^#' .testnet_env | xargs)
echo $MYC $ESMYC $TEST_WETH

rewardTrackerOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/RewardTracker.sol:RewardTracker)
arr=($rewardTrackerOutput)
rewardTracker=${arr[9]}
echo "Deployed rewardTracker to address ${rewardTracker}"

rewardDistributorOutput=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY src/V2/RewardDistributor.sol:RewardDistributor)
arr=($rewardDistributorOutput)
rewardDistributor=${arr[9]}
echo "Deployed rewardDistributor to address ${rewardDistributor}"

echo "Initializing Reward Tracker..."
echo $gov "stakedMYC" "sMYC" "[$MYC,$ESMYC]" $gov

a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardTracker \
    "initialize(address,string,string,address[],address)" \
    $gov "stakedMYC" "sMYC" "[$MYC,$ESMYC]" $gov)

echo "Initializing Reward Distributor..."
echo $gov $RPC_URL $rewardDistributor

a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $rewardDistributor \
    "initialize(address,address,address)" \
    $gov $TEST_WETH $rewardTracker)

echo "Initialization complete."