ethRewards="1000000000000"
lossAmount="0"
withdrawAmount="0"

cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "setPreCycleTimelock(uint256)" "1000000" > /dev/null
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --value $ethRewards $LMYC "newCycle(uint256,uint256)" $lossAmount $withdrawAmount
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "setPreCycleTimelock(uint256)" "5" > /dev/null