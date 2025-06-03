import { ethers } from "hardhat";
import { ZeroAddress } from "ethers"

const pythContract_testnet = ""
const flowusd_identifier = ""

const NFTSale_USD_COST = 1000;

const firstOwnerAddress = ""

async function main() {
    const PriceFeedFactory = await ethers.getContract("FlowUsdPriceFeed");
    const priceFeed = await PriceFeedFactory.deploy(pythContract_testnet, flowusd_identifier)
    await priceFeed.deployed();

    const RandProviderFactory = await ethers.getContract("RandProvider");
    const randProvider = await RandProviderFactory.deploy();
    await randProvider.deployed();

    const priceFeedAddress = priceFeed.address;
    const randProviderAddress = randProvider.address;

    const NFTSaleFactory = await ethers.getContract("NFTSale");
    const nftSale = await NFTSaleFactory.deploy(NFTSale_USD_COST, priceFeedAddress);

    await nftSale.deployed();

    const nftSaleAddress = nftSale.address;

    const mintParameters = {
        to: firstOwnerAddress,
        erc20Address: ZeroAddress,
        winnerPrizeShare: 10, // 10% share
        diceRollCost: ethers.parseEther("1"), // 1 Flow to roll
        houseEdge: 10, // 10% house edge
        revealCompensation: ethers.parseEther("0.01"), // Flow to roll, should cover the gas fees
        min: 1,
        max: 6
    }


    const FlowRollNFTFactory = await ethers.getContract("FlowRollNFT");
    const flowRollNft = await FlowRollNFTFactory.deploy(
        randProviderAddress,
        nftSaleAddress,
        mintParameters.to,
        mintParameters.erc20Address,
        mintParameters.winnerPrizeShare,
        mintParameters.diceRollCost.
            mintParameters.houseEdge,
        mintParameters.revealCompensation,
        mintParameters.min,
        mintParameters.max
    );


    await flowRollNft.deployed().then(async () => {
        await nftSale.setNFTAddress(flowRollNft.address)
        await flowRollNft.setProtocolFee(10);
    })


    console.log("DONE")
}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
})