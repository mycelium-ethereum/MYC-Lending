// require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.13",
    networks: {
        hardhat: {
            // gas: 900000000000000,
            // blockGasLimit: 10000000000000,
            allowUnlimitedContractSize: true
        }
    }
};
