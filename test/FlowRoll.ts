import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseGwei, parseEther, zeroAddress } from "viem";

describe("FlowRoll with mocked randomness dependency", function () {

  async function loadDeployFixture() {
    const [owner, account2] = await hre.viem.getWalletClients();
    const MockRandProvider = await hre.viem.deployContract("MockRandProvider");
    const publicClient = await hre.viem.getPublicClient();
    const SALEPRICE = parseEther("10");

    //@ts-ignore - ignoring that it wants to deploy cadenceArch
    const NFTSale = await hre.viem.deployContract("NFTSale", [SALEPRICE])

    const WINNERPRIZESHARE = 10; // 10% of the prizeVault goes to the winner
    const DICEROLLCOST = parseEther("0.01");
    const HOUSEEDGE = 10; //10% of the win or loss goes to the house
    const REVEALCOMPENSATION = parseEther("0.001"); // Compensation for revealing the result of the dice roll
    const MIN = 1; //The minimum number that can be rolled
    const MAX = 6; //The max, it's a 6 sided dice for now

    //@ts-ignore - ignoring that it wants to deploy cadenceArch instead of FlowRollNFT for some weird reason
    const FlowRollNFT = await hre.viem.deployContract("FlowRollNFT", [
      MockRandProvider.address,
      NFTSale.address,
      owner.account.address,
      zeroAddress, //Will use ETH for deposits
      WINNERPRIZESHARE,
      DICEROLLCOST,
      HOUSEEDGE,
      REVEALCOMPENSATION,
      MIN,
      MAX
    ])


    return {
      MockRandProvider,
      publicClient,
      owner,
      account2,
      FlowRollNFT
    }
  }

  describe("Deployment", function () {
    it("Should all just deploy", function () {
      const { MockRandProvider, NFTSale, publicClient, owner, account2, FlowRollNFT } = loadDeployFixture()

      //TODO: Do the tests here
      console.log("tests here")
    })
  })

});