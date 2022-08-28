address="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"

echo "lentMYC.totalSupply: "
echo "1"
deposits=`cast call --rpc-url $RPC_URL $LMYC "userPendingDeposits(address)" $address`
echo $deposits
printf "Pending Deposits: %d\n" $deposits
redeems=`cast call --rpc-url $RPC_URL $LMYC "userPendingRedeems(address)" $address`
printf "Pending Redeems: %d\n" $redeems
claimable=`cast call --rpc-url $RPC_URL $LMYC "getClaimableAmount(address)" $address`
printf "Claimable ETH: %d\n" $claimable
