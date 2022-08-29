address="0xE6F183a130D3a68Eb8Bf4314F3aA51f1d0013540"

echo "lentMYC.totalSupply: "
echo "1"
deposits=`cast call --rpc-url $RPC_URL $LMYC "userPendingDeposits(address)" $address`
printf "Pending Deposits: ${deposits}\n"
redeems=`cast call --rpc-url $RPC_URL $LMYC "userPendingRedeems(address)" $address`
printf "Pending Redeems: ${redeems}\n"
claimable=`cast call --rpc-url $RPC_URL $LMYC "getClaimableAmount(address)" $address`
printf "Claimable ETH: ${claimable}\n"

trueBal=`cast call --rpc-url $RPC_URL $LMYC "trueBalanceOf(address)" $address`
printf "True balance of: ${trueBal}\n"