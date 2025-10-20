import { ethers } from "hardhat";

import {parseEther} from "ethers"
async function main() {
    // const NFTSale_V2 = await ethers.getContractFactory("NFTSale_v2");
    // const c = await NFTSale_V2.deploy(parseEther("2000"));

    // console.log("NFTSale_v2 deployed to:", c.target);

    // const nft = await ethers.getContractAt("FlowRollNFT", "0x5219333BEeD9c98A0D0A625C9e5578A9DaAa94Ff")

    // const tx = await nft.changeNFTSaleContract(c.target).catch(err =>{
    //     console.error(err)
    //     console.log('Error when changing nft sale contract address')
    // });

    // const receipt = await tx.wait();

    // console.log(receipt)

    //SETTING THE NFT ADDRESS
    const NFTSale_V2 = await ethers.getContractAt("NFTSale_v2","0x67E9A2e94DF5328F5b0DD97083EA15CCe71E17ED")
    const tx = await NFTSale_V2.setNFTAddress("0x5219333BEeD9c98A0D0A625C9e5578A9DaAa94Ff").catch(err =>{
        console.log(err)

    })

    const receipt = await tx.wait()
    console.log(receipt)

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });

// NFTSale_v2 deployed to: 0x67E9A2e94DF5328F5b0DD97083EA15CCe71E17ED