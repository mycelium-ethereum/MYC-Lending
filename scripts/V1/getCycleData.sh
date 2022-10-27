preCycleTimelock=`cast call --rpc-url $RPC_URL $LMYC "preCycleTimelock()"`
cycleStartTime=`cast call --rpc-url $RPC_URL $LMYC "cycleStartTime()"`
cycleLength=`cast call --rpc-url $RPC_URL $LMYC "cycleLength()"`
echo $cycleLength
echo $preCycleTimelock
echo $cycleStartTime
cycleWindowClose=$((cycleStartTime + cycleLength - preCycleTimelock))
echo "Deposit window closing in approx $((cycleWindowClose - $(date +%s))) seconds."
echo ""
echo "Total Supply: $(cast call --rpc-url $RPC_URL $LMYC "totalSupply()")"
echo ""
echo "totalAssets: $(cast call --rpc-url $RPC_URL $LMYC "totalAssets()")"
echo ""
echo "Pending Deposits: $(cast call --rpc-url $RPC_URL $LMYC "pendingDeposits()")"
echo ""
echo "Pending Redeems: $(cast call --rpc-url $RPC_URL $LMYC "pendingRedeems()")"
echo ""
echo "ETH balance: $(cast balance --rpc-url $RPC_URL $LMYC)"
