gov="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"
decimals="18"
cycleLength="300" # 5 minutes
firstCycleStart="1661235795"
preCycleTimelock="60"
# 100,000
depositCap="100000000000000000000000"

forge build

mycTokenOutput=$(forge create --rpc-url $RPC_URL --constructor-args "Mycelium" "MYC" "18" --private-key $PRIVATE_KEY src/Myc.sol:Myc)
arr=($mycTokenOutput)
myc=${arr[9]}
echo "Deployed test MYC to address ${myc}"

lentMycOutput=$(forge create --rpc-url $RPC_URL \
    --constructor-args $myc $gov $decimals $cycleLength $firstCycleStart $preCycleTimelock $depositCap \
    --private-key $PRIVATE_KEY src/LentMyc.sol:LentMyc)

echo "lentMycOutput: ${lentMycOutput}"

arr2=($lentMycOutput)
lMyc=${arr2[9]}

echo " "
echo "lentMYC deployed to address ${lMyc}"

dummyMycBuyer=$(forge create --rpc-url $RPC_URL \
    --constructor-args $myc $gov \
    --private-key $PRIVATE_KEY src/DummyMycBuyer.sol:DummyMycBuyer)

echo "dummyMycBuyer output: ${dummyMycBuyer}"

arr3=($dummyMycBuyer)
dummyMycBuyer=${arr3[9]}

echo " "
echo "setting mycBuyer"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $lMyc "setMycBuyer(address)" $dummyMycBuyer

echo " "
echo "dummyMycBuyer deployed to address ${dummyMycBuyer}"

# 100m
balanceToTransfer="100000000000000000000000000"
echo "Transferring ${balanceToTransfer} to the dummyMycBuyer"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $myc "transfer(address,uint256)" $dummyMycBuyer $balanceToTransfer

faucetOutput=$(forge create --rpc-url $RPC_URL \
    --constructor-args $myc \
    --private-key $PRIVATE_KEY src/TestnetFaucet.sol:TestnetFaucet)
echo "faucet output: ${faucetOutput}"
arr4=($faucetOutput)
faucet=${arr4[9]}
echo " "
echo "faucet deployed to address ${faucet}"

echo "Transferring ${balanceToTransfer} to the faucet"
cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $myc "transfer(address,uint256)" $faucet $balanceToTransfer

# forge verify-contract ${lMyc} src/LentMyc.sol:LentMyc
