echo "lentMYC.totalSupply: "
echo "1"
deposits=`cast call --rpc-url $RPC_URL $LMYC "userPendingDeposits(address)" $ACCOUNT`
printf "Pending Deposits: ${deposits}\n"
redeems=`cast call --rpc-url $RPC_URL $LMYC "userPendingRedeems(address)" $ACCOUNT`
printf "Pending Redeems: ${redeems}\n"
claimable=`cast call --rpc-url $RPC_URL $LMYC "getClaimableAmount(address)" $ACCOUNT`
printf "Claimable ETH: ${claimable}\n"

trueBal=`cast call --rpc-url $RPC_URL $LMYC "trueBalanceOf(address)" $ACCOUNT`
printf "True balance of: ${trueBal}\n"