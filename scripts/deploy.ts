import { ethers } from "hardhat";
import { ZeroAddress } from "ethers"

const pythContract_testnet = "0x2880aB155794e7179c9eE2e38200202908C17B43"
const flowusd_identifier = "0x2fb245b9a84554a0f15aa123cbb5f64cd263b59e9a87d80148cbffab50c69f30"

const NFTSale_USD_COST = 1000;

const firstOwnerAddress = "0x0000000000000000000000028fd6267C8D7d566f"

async function main() {

    await deployerDetails()
    const PriceFeedFactory = await ethers.getContractFactory("FlowUsdPriceFeed");
    const priceFeed = await PriceFeedFactory.deploy(pythContract_testnet, flowusd_identifier, {})
    
    log("PriceFeed", priceFeed.target)
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

// $ npx hardhat run scripts/deploy.ts --network flowTestnet
// Deploying contracts with the account: 0xa1603F0fAA3d93eaa3B8c31a5340f82719616940
// Deployer balance: 99999.9982069015 FLow 
// PriceFeed address : 0xebA57ebA9d4d7c1D3390656575cD3Fb0CB353c5C
// RandProvider address : 0xb774Cb914e1C8B33e33830b529707Bf4bc11E67a
// NFTSale address : 0x02627acB81E56b041292144fa294B590906B01d8
// flowRollNFT address : 0xa9E44221D40063934BB63955b230FD5f2A60c717
// NFT address set to:  0xa9E44221D40063934BB63955b230FD5f2A60c717
// protocol fee is set to 10%
// DONE
// Deploying contracts with the account: 0xa1603F0fAA3d93eaa3B8c31a5340f82719616940
// Deployer balance: 99999.9974161294 FLow 