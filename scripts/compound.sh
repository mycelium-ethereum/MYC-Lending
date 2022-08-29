recipient="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"

echo "=========== COMPOUNDING ==========="
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "compound(address, bytes)" $recipient ""
