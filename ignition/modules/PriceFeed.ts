//This uses Hardhat Ignition to deploy the price feed contract, it uses Pyth on Flow
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const PYTHCONTRACT_TESTNET = ""
const FLOWUSD_PYTH_IDENTIFIER_TESTNET = ""

const PriceFeedModule = buildModule("PriceFeed", (m) => {
    const priceFeed = m.contract("PriceFeed", [PYTHCONTRACT_TESTNET, FLOWUSD_PYTH_IDENTIFIER_TESTNET], {})

    return { priceFeed }
})

export default PriceFeedModule