mycLend="0x7707FDb2e8a05Af7889faa52670D35aae8970E74"
myc="0x14F30079b4a6650e4729B123b9E8d122F912FaB5"
recipient="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"

echo "Depositing $1 MYC"

echo "============ APPROVING ============"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $myc "approve(address,uint256)" $mycLend $1
echo "=========== TRANSFERING ==========="
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $mycLend "deposit(uint256,address)" $1 $recipient
