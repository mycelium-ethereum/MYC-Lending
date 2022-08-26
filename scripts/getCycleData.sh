mycLend="0x7707FDb2e8a05Af7889faa52670D35aae8970E74"

echo "lentMYC.totalSupply: "
echo "1"
echo `cast call --rpc-url $RPC_URL $mycLend "totalSupply()"`
echo "2"
echo `cast call --rpc-url $RPC_URL $mycLend "totalAssets()"`
echo "2"
echo `cast call --rpc-url $RPC_URL $mycLend "preCycleTimelock()"`
echo "3"