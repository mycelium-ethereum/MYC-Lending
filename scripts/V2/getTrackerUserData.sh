echo "1"
deposits=`cast call --rpc-url $RPC_URL $REWARD_TRACKER_PROXY "totalDepositSupply(address)" $MYC`
printf "MYC Deposits: ${deposits}\n"

staked=`cast call --rpc-url $RPC_URL $REWARD_TRACKER_PROXY "stakedAmounts(address)" $ACCOUNT`
printf "User Stake: ${staked}\n"