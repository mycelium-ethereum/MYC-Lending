gov="0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac"
decimals="18"
cycleLength="604800" # 5 minutes
firstCycleStart="1662530569"
preCycleTimelock="7200"
# 10,000,000
depositCap="10000000000000000000000000"
admin="0x3E2d84477631691cC49B75a41bAe7ca8e032E8ac"
myc="0xC74fE4c715510Ec2F8C61d70D397B32043F55Abe"

forge build

lentMycOutput=$(forge create --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY src/LentMyc.sol:LentMyc)

arr2=($lentMycOutput)
lMyc=${arr2[9]}

echo " "
echo "IMPLEMENTATION: lentMYC deployed to address ${lMyc}"

zeroAdd="0x0000000000000000000000000000000000000000"

echo "Initializing implementation..."
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $lMyc \
    "initialize(address,address,uint256,uint256,uint256,uint256,address)" \
    $zeroAdd $zeroAdd "0" "0" "0" "0" $zeroAdd)

forge build
echo "Deploying proxy"
proxy=$(forge create --rpc-url $RPC_URL \
    --constructor-args $lMyc "" \
    --private-key $PRIVATE_KEY src/ERC1967Proxy.sol:ERC1967Proxy)

echo "Deployed proxy"
echo $proxy
proxyArr=($proxy)
echo "Deployed proxy"
proxy=${proxyArr[9]}

echo " "
echo "PROXY: lentMYC proxy deployed to address ${proxy}"

echo "Initializing..."
echo $myc $gov $cycleLength $firstCycleStart $preCycleTimelock $depositCap $admin
a=$(cast send --rpc-url \
    $RPC_URL --private-key $PRIVATE_KEY $proxy \
    "initialize(address,address,uint256,uint256,uint256,uint256,address)" \
    $myc $gov $cycleLength $firstCycleStart $preCycleTimelock $depositCap $admin)
