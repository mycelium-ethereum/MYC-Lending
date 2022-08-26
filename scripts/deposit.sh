recipient="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"

echo "Depositing $1 MYC"

echo "============ APPROVING ============"
# cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $MYC "approve(address,uint256)" $LMYC "10000000000000000000000000000000000"
echo "=========== TRANSFERING ==========="
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "deposit(uint256,address)" $1 $recipient
