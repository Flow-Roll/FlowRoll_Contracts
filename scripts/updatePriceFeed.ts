import { ethers } from "hardhat";
import { ZeroAddress } from "ethers"

async function rand() {
    const c = await ethers.getContractAt("RandProvider", "0x26A0E1656B22222Ec307fF67aF83Cd116Da750be")


}

async function main() {
    const addr = ""
    const c = await ethers.getContractAt("OwnedReplacementFlowUSDPriceFeed", addr);

    const price = 34075200
    const expo = -8

    await c.setPrice(price, expo)

}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
})