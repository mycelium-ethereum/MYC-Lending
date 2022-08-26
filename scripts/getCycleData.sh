echo "Total Supply: $(cast call --rpc-url $RPC_URL $LMYC "totalSupply()")"
echo ""
echo "totalAssets: $(cast call --rpc-url $RPC_URL $LMYC "totalAssets()")"
echo ""
preCycleTimelock=`cast call --rpc-url $RPC_URL $LMYC "preCycleTimelock()"`
cycleStartTime=`cast call --rpc-url $RPC_URL $LMYC "cycleStartTime()"`
cycleLength=`cast call --rpc-url $RPC_URL $LMYC "cycleLength()"`
cycleWindowClose=$((cycleStartTime + cycleLength - preCycleTimelock))
echo "Deposit window closing in approx $((cycleWindowClose - $(date +%s))) seconds."