gov="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"
decimals="18"
cycleLength="300" # 5 minutes
firstCycleStart="1661235795"
preCycleTimelock="60"
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
lMyc=${arr[9]}

echo " "
echo "lentMYC deployed to address ${lMyc}"

# forge verify-contract ${lMyc} src/LentMyc.sol:LentMyc
