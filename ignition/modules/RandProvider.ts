// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther } from "viem";

const RandProviderModule = buildModule("RandProvider", (m) => {
    const randProvider = m.contract("RandProvider", [], {})

    return { randProvider }
})

export default RandProviderModule