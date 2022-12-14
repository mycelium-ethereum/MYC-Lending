// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
    // scripts/create-box.js
    const { ethers, upgrades } = require("hardhat");

    async function main() {
        const signers = await ethers.getSigners()
        const LentMyc = await ethers.getContractFactory("LentMyc");
        const lMyc = await upgrades.deployProxy(LentMyc, [ethers.constants.AddressZero, signers[0].address, 0, 0, 0, 0, signers[0].address]);
        await lMyc.deployed();
        console.log("lMyc deployed to:", lMyc.address);
        const LentMycV2 = await ethers.getContractFactory("LentMycWithMigration");
        console.log(1)
        const lMyc2 = await upgrades.upgradeProxy(lMyc.address, LentMycV2);
        console.log("lMyc2 upgraded to:", lMyc2.address);

        const RewardTracker = await ethers.getContractFactory("RewardTracker");
        const rewardTracker = await upgrades.deployProxy(RewardTracker, [signers[0].address, "Staked MYC", "sMYC", [], ethers.constants.AddressZero]);
        await rewardTracker.deployed();
        console.log("rewardTracker deployed to:", rewardTracker.address);

        const RewardDistributor = await ethers.getContractFactory("RewardDistributor");
        const rewardDistributor = await upgrades.deployProxy(RewardDistributor, [signers[0].address, ethers.constants.AddressZero, ethers.constants.AddressZero]);
        await rewardDistributor.deployed();
        console.log("rewardDistributor deployed to:", rewardDistributor.address);
    }

    main();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
