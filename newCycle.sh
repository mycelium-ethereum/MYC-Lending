ethRewards="0"
lossAmount="0"
withdrawAmount="0"
mycLend="0x52B88DB0320295209861a4EADab81E58a7cEB4f9"

cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY --value $ethRewards $mycLend "newCycle(uint256,uint256)" $lossAmount $withdrawAmount