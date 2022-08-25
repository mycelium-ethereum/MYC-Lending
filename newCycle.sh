ethRewards="0"
lossAmount="0"
withdrawAmount="0"
mycLend="0x7707FDb2e8a05Af7889faa52670D35aae8970E74"

while :
do
    cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --value $ethRewards $mycLend "newCycle(uint256,uint256)" $lossAmount $withdrawAmount
    sleep 5m
done