import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const USDCOST = 1000; /// 1000 USD
const PRICEFEEDADDRESS = "";

const NFTSaleModule = buildModule("NFTSale", (m) => {
    const usdCost = m.getParameter("_USDcost", USDCOST)
    const priceFeedContract = m.getParameter("_priceFeedContract", PRICEFEEDADDRESS)

    const NFTSale = m.contract("NFTSale", [usdCost, priceFeedContract]);


    return { NFTSale }
})

export default NFTSaleModule

