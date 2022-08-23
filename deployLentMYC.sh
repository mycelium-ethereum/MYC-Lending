myc="0xCBA0e7B2EF0f70EB210aA7758A06Bab9230aC435"
gov="0xc18fcFFD8c9173faB1684Ec1EEE32976f780B13E"
decimals="18"
cycleLength="300" # 5 minutes
firstCycleStart="1661235795"
preCycleTimelock="60"
depositCap="100000000000000000000000"

forge create --rpc-url $RPC_URL \
    --constructor-args $myc $gov $decimals $cycleLength $firstCycleStart $preCycleTimelock $depositCap \
    --private-key $PRIVATE_KEY src/LentMyc.sol:LentMyc

