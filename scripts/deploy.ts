import { ethers } from "hardhat";
import { ZeroAddress } from "ethers"

const NFTSale_USD_COST = 1000;

const firstOwnerAddress = "0x0000000000000000000000028fd6267C8D7d566f"

async function main() {

    await deployerDetails()
    const PriceFeedFactory = await ethers.getContractFactory("OwnedReplacementFlowUSDPriceFeed");
    const priceFeed = await PriceFeedFactory.deploy()

    log("PriceFeed", priceFeed.target)
    await priceFeed.setPrice(34075200,-8)
    const RandProviderFactory = await ethers.getContractFactory("RandProvider");
    const randProvider = await RandProviderFactory.deploy();

    log("RandProvider", randProvider.target)
    const priceFeedAddress = priceFeed.target;
    const randProviderAddress = randProvider.target;

    const NFTSaleFactory = await ethers.getContractFactory("NFTSale");
    const nftSale = await NFTSaleFactory.deploy(NFTSale_USD_COST, priceFeedAddress, {});


    const nftSaleAddress = nftSale.target;
    log("NFTSale", nftSaleAddress)

    const mintParameters = {
        to: firstOwnerAddress,
        erc20Address: ZeroAddress,
        winnerPrizeShare: 10, // 10% share
        diceRollCost: ethers.parseEther("1"), // 1 Flow to roll
        houseEdge: 10, // 10% house edge
        revealCompensation: ethers.parseEther("0.01"), // Flow to roll, should cover the gas fees
        min: 1,
        max: 6,
        betType: 0
    }


    const FlowRollNFTFactory = await ethers.getContractFactory("FlowRollNFT");
    const flowRollNft = await FlowRollNFTFactory.deploy(
        randProviderAddress,
        nftSaleAddress,
        mintParameters.to,
        mintParameters.erc20Address,
        mintParameters.winnerPrizeShare,
        mintParameters.diceRollCost,
        mintParameters.houseEdge,
        mintParameters.revealCompensation,
        [mintParameters.min, mintParameters.max, mintParameters.betType],
        {}
    );

    log("flowRollNFT", flowRollNft.target)
    await nftSale.setNFTAddress(flowRollNft.target)
    console.log("NFT address set to: ", flowRollNft.target)
    await flowRollNft.setProtocolFee(10);
    console.log("protocol fee is set to 10%")

    console.log("DONE")
    await deployerDetails()
}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
})

function log(name: string, address: string) {
    console.log(`${name} address : ${address}`)
}

async function deployerDetails() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("Deployer balance:", ethers.formatEther(balance), "FLow ");
}

//LAST DEPLOYMENT LOGS:


// Compiled 1 Solidity file successfully (evm target: paris).
// Deploying contracts with the account: 0xa1603F0fAA3d93eaa3B8c31a5340f82719616940
// Deployer balance: 99999.9949322098 FLow 
// PriceFeed address : 0x828696c50aF41F5Fa157a62825ba79EF2789B616
// RandProvider address : 0x19beb924D80a32FE87f84C08c63f4F0C2dDCaE61
// NFTSale address : 0x0343291e9b3F39eD8DAecad2c0C49945d4Ee2fd6
// flowRollNFT address : 0x5FE4E3CD96237CEdcF7D8C6313d0FaD8A98Ab1B4
// NFT address set to:  0x5FE4E3CD96237CEdcF7D8C6313d0FaD8A98Ab1B4
// protocol fee is set to 10%
// DONE
// Deploying contracts with the account: 0xa1603F0fAA3d93eaa3B8c31a5340f82719616940
// Deployer balance: 99999.994120365 FLow 