echo "Depositing $1 MYC"

echo "============ APPROVING ============"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $MYC "approve(address,uint256)" $LMYC "10000000000000000000000000000000000"
echo "============= DEPOSIT ============="
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $LMYC "deposit(uint256,address)" $1 $ACCOUNT
