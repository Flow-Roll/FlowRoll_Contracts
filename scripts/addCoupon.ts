import { ethers } from "hardhat";



const NEWCOUPON = "#GoWithTheFlow"
// const RECIPENT = "";
const PERCENTAGEOFF = 90;
const COMMISSION = 50;
const _COUPONUSESLEFT = 10;

async function main() {
    const [signer] = await ethers.getSigners();
    const RECIPENT = await signer.getAddress();


    const c = await ethers.getContractAt("NFTSale", "0x17664E960a1445434A460fBAAf6d361FcD04396c")

    const tx = await c.setCoupon(
        NEWCOUPON,
        RECIPENT,
        PERCENTAGEOFF,
        COMMISSION,
        _COUPONUSESLEFT, {}).catch(err => {
            console.error(err)
        });

    const receipt = await tx.wait();

    console.log(receipt);
}

main().catch((err) => {
    console.error(err);
    process.exitCode = 1;
})