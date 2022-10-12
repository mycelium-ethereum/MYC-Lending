echo "=========== CLAIMING ==========="
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "claim(bool,bytes)" "true" ""
