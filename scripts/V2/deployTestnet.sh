decimals="18"
cycleLength="70"
firstCycleStart="1661235795"
preCycleTimelock="5"
# 100,000
depositCap="100000000000000000000000"

forge build

mycTokenOutput=$(forge create --rpc-url $RPC_URL \
    --constructor-args "Mycelium" "MYC" "18" \
    --private-key $PRIVATE_KEY src/token/Myc.sol:Myc)
arr=($mycTokenOutput)
myc=${arr[9]}
echo "Deployed test MYC to address ${myc}"

mycTokenOutput=$(forge create --rpc-url $RPC_URL \
    --constructor-args "Escrowed Mycelium" "esMYC" "18" \
    --private-key $PRIVATE_KEY src/token/Myc.sol:Myc)
arr=($mycTokenOutput)
esMyc=${arr[9]}
echo "Deployed test esMYC to address ${esMyc}"

wethOutput=$(forge create --rpc-url $RPC_URL \
    --constructor-args "Wrapped Ether" "WETH" "18" \
    --private-key $PRIVATE_KEY src/token/Token.sol:Token)
arr=($wethOutput)
weth=${arr[9]}
echo "Deployed test WETH to address ${weth}"

lentMycOutput=$(forge create --rpc-url $RPC_URL \
    --constructor-args \ # $myc $gov $decimals $cycleLength $firstCycleStart $preCycleTimelock $depositCap \
    --private-key $PRIVATE_KEY src/V1/LentMyc.sol:LentMyc)

# echo "lentMycOutput: ${lentMycOutput}"

arr2=($lentMycOutput)
lMyc=${arr2[9]}

echo " "
echo "IMPLEMENTATION: lentMYC deployed to address ${lMyc}"

echo "Deploying proxy"
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $lMyc "" \
    --private-key $PRIVATE_KEY lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy)

proxyArr=($proxy)
echo "Deployed proxy"
proxy=${proxyArr[9]}
echo "PROXY: lentMYC proxy deployed to address ${proxy}"
echo " "

echo "Initializing..."
echo $myc $ACCOUNT $cycleLength $firstCycleStart $preCycleTimelock $depositCap $ACCOUNT
cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $proxy \
    "initialize(address,address,uint256,uint256,uint256,uint256,address)" \
    $myc $ACCOUNT $cycleLength $firstCycleStart $preCycleTimelock $depositCap $ACCOUNT

dummyMycBuyer=$(forge create --rpc-url $RPC_URL \
    --constructor-args $myc $ACCOUNT \
    --private-key $PRIVATE_KEY src/V1/DummyMycBuyer.sol:DummyMycBuyer)

# echo "dummyMycBuyer output: ${dummyMycBuyer}"

arr3=($dummyMycBuyer)
dummyMycBuyer=${arr3[9]}

echo " "
echo "setting mycBuyer"
a=`cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $proxy "setMycBuyer(address)" $dummyMycBuyer`

echo " "
echo "dummyMycBuyer deployed to address ${dummyMycBuyer}"

# 100m
balanceToTransfer="100000000000000000000000000"
echo "Transferring ${balanceToTransfer} to the dummyMycBuyer"
a=`cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $myc "transfer(address,uint256)" $dummyMycBuyer $balanceToTransfer`

faucetOutput=$(forge create --rpc-url $RPC_URL \
    --constructor-args $myc \
    --private-key $PRIVATE_KEY src/token/TestnetFaucet.sol:TestnetFaucet)
# echo "faucet output: ${faucetOutput}"
arr4=($faucetOutput)
faucet=${arr4[9]}
echo " "
echo "faucet deployed to address ${faucet}"

echo "Transferring ${balanceToTransfer} to the faucet"
a=`cast send --rpc-url $RPC_URL --private-key $PRIVATE_KEY $myc "transfer(address,uint256)" $faucet $balanceToTransfer`

echo "\`export MYC=${myc} ; export esMYC=${esMyc} ; export LMYC=${proxy} ; export WETH=${weth} ; export LMYC_V1_IMPL=${lMyc}\`"