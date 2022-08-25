ethRewards="100000000"
lossAmount="0"
withdrawAmount="0"
mycLend="0xB6463D7E8Bf4d532C826Db8Ac6Ad41d525C4f72d"

while :
do
    cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --value $ethRewards $mycLend "newCycle(uint256,uint256)" $lossAmount $withdrawAmount
    sleep 5m
done