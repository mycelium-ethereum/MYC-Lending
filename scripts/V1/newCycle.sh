ethRewards="10000000000000"
lossAmount="0"
withdrawAmount="0"

while :
do
    cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --value $ethRewards $LMYC "newCycle(uint256,uint256)" $lossAmount $withdrawAmount
    sleep 250s
done