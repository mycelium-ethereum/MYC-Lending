mycLend="0xB6463D7E8Bf4d532C826Db8Ac6Ad41d525C4f72d"
myc="0x3e149A47CA56ee53bd54ead4ccE8D90A058304Df"
recipient="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"

echo "Depositing $1 MYC"

echo "============ APPROVING ============"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $myc "approve(address,uint256)" $mycLend $1
echo "=========== TRANSFERING ==========="
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $mycLend "deposit(uint256,address)" $1 $recipient
