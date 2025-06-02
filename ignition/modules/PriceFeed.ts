//This uses Hardhat Ignition to deploy the price feed contract, it uses Pyth on Flow
import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const PYTHCONTRACT_TESTNET = ""
const FLOWUSD_PYTH_IDENTIFIER_TESTNET = ""

const PriceFeedModule = buildModule("PriceFeed", (m) => {
    const oracle_address = m.getParameter("pythContract", PYTHCONTRACT_TESTNET)
    const identifier = m.getParameter("_flowusd_identifier", FLOWUSD_PYTH_IDENTIFIER_TESTNET)
    const priceFeed = m.contract("PriceFeed", [oracle_address, identifier], {})

    return { priceFeed }
})

export default PriceFeedModule