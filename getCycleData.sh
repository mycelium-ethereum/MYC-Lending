mycLend="0x52B88DB0320295209861a4EADab81E58a7cEB4f9"

echo "lentMYC.totalSupply: "
echo `cast call --rpc-url $RPC_URL $mycLend "totalSupply()"`
echo `cast call --rpc-url $RPC_URL $mycLend "totalAssets()"`