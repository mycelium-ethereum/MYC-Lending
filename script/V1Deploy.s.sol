// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/V1/LentMyc.sol";
import {Myc} from "src/token/Myc.sol";
import {Token} from "src/token/Token.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TestnetFaucet} from "src/token/TestnetFaucet.sol";

contract DeployV1Script is Script {
    address gov;
    address admin;
    uint256 decimals = 18;
    uint256 cycleLength = 300;
    uint256 firstCycleStart = block.timestamp;
    uint256 preCycleTimelock = 60;
    uint256 depositCap = 100000000000000000000000;

    function setUp() public {}

    function run() public {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        gov = msg.sender;
        admin = gov;
        vm.startBroadcast();
        Myc myc = new Myc("Mycelium", "MYC", 18);
        Myc esMyc = new Myc("Escrowed Mycelium", "esMYC", 18);
        Token WETH = new Token("Testnet Wrapped Ether", "WETH", 18);
        LentMyc lMyc = new LentMyc();

        // Initialize the implementation.
        lMyc.initialize(address(0), address(0), 0, 0, 0, 0, address(0));

        ERC1967Proxy proxy = new ERC1967Proxy(address(lMyc), "");
        LentMyc lproxy = LentMyc(address(proxy));

        // Initialize the proxy.
        lproxy.initialize(
            address(myc),
            gov,
            cycleLength,
            firstCycleStart,
            preCycleTimelock,
            depositCap,
            admin
        );
        console.log("lproxy gov: %s", lproxy.gov());

        TestnetFaucet faucet = new TestnetFaucet(address(myc));
        TestnetFaucet esFaucet = new TestnetFaucet(address(esMyc));

        myc.transfer(address(faucet), myc.balanceOf(msg.sender));
        esMyc.transfer(address(esFaucet), myc.balanceOf(msg.sender));

        faucet.drip();

        console.log("MYC: %s", address(myc));
        console.log("esMYC: %s", address(esMyc));
        console.log("WETH : %s", address(WETH));
        console.log("Implementation: %s", address(lMyc));
        console.log("Proxy: %s", address(lproxy));
        console.log("MYC Faucet: %s", address(faucet));
        console.log("esMYC Faucet: %s", address(esFaucet));
        console.log(
            "export MYC=%s ; export esMYC=%s ; export LMYC=%s ; ",
            address(myc),
            address(esMyc),
            address(lproxy)
        );
        console.log(
            "export WETH=%s ; export LMYC_V1_IMPL=%s ; export FAUCET=%s",
            address(WETH),
            address(lMyc),
            address(faucet)
        );
        vm.stopBroadcast();
    }
}
