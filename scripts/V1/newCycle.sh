ethRewards="1000000000000"
lossAmount="0"
withdrawAmount="0"

while :
do
    # curl -H "Content-Type: application/json" -X POST --data \
    # '{"jsonrpc":"2.0","method":"evm_increaseTime","params":[180],"id":31337}' $RPC_URL
    cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "setPreCycleTimelock(uint256)" "1000000" > /dev/null
    cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --value $ethRewards $LMYC "newCycle(uint256,uint256)" $lossAmount $withdrawAmount
    cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "setPreCycleTimelock(uint256)" "5" > /dev/null
    exit 0
    sleep 250s
done

 curl -H "Content-Type: application/json" -X POST --data \
     '{"jsonrpc":"2.0","method":"evm_increaseTime","params":[180],"id":31337}' $RPC_URL