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

// Deploying contracts with the account: 0xa1603F0fAA3d93eaa3B8c31a5340f82719616940
// Deployer balance: 99999.9914376411 FLow 
// PriceFeed address : 0x883faFA50750B3Fa8628D326104f242867618ed8
// RandProvider address : 0x1D9822f20FF7f4275731710EF8bD1F01B0335d86
// NFTSale address : 0x17664E960a1445434A460fBAAf6d361FcD04396c
// flowRollNFT address : 0x5219333BEeD9c98A0D0A625C9e5578A9DaAa94Ff
// NFT address set to:  0x5219333BEeD9c98A0D0A625C9e5578A9DaAa94Ff
// protocol fee is set to 10%
// DONE
// Deploying contracts with the account: 0xa1603F0fAA3d93eaa3B8c31a5340f82719616940
// Deployer balance: 99999.9906150637 FLow 