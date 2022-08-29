recipient="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"

echo "Redeem $1 MYC"

echo "=========== TRANSFERING ==========="
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "redeem(uint256,address, address)" $1 $recipient $recipient
