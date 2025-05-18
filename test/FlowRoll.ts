import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseGwei, parseEther, zeroAddress } from "viem";

describe("FlowRoll with mocked randomness dependency", function () {

  async function deployFixture() {
    const [owner, account2] = await hre.viem.getWalletClients();
    const MockRandProvider = await hre.viem.deployContract("MockRandProvider");
    const publicClient = await hre.viem.getPublicClient();
    const SALEPRICE = parseEther("10");


    const NFTSale = await hre.viem.deployContract("NFTSale", [SALEPRICE])

    const WINNERPRIZESHARE = 10; // 10% of the prizeVault goes to the winner
    const DICEROLLCOST = parseEther("0.01");
    const HOUSEEDGE = 10; //10% of the win or loss goes to the house
    const REVEALCOMPENSATION = parseEther("0.001"); // Compensation for revealing the result of the dice roll
    const MIN = 1; //The minimum number that can be rolled
    const MAX = 6; //The max, it's a 6 sided dice for now


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
      FlowRollNFT,
      NFTSale
    }
  }

  describe("Deployment", function () {
    it("Should all just deploy", async function () {
      const { MockRandProvider, NFTSale, publicClient, owner, account2, FlowRollNFT } = await loadFixture(deployFixture)

      //Check that there is one NFT minted for owner and has a flowRoll contract
      const ownerBalance = await FlowRollNFT.read.balanceOf([owner.account.address]);

      expect(ownerBalance).to.equal(1n)

      //Expect that the NFT owned by the owner has an index 0
      const ownersNFT = await FlowRollNFT.read.ownerOf([0n]);
      expect(ownersNFT.toLowerCase()).to.equal(owner.account.address.toLowerCase());

      //MAX mint is 1000 and current mint is 1
      const MAXMINT = await FlowRollNFT.read.MAXMINT();
      expect(MAXMINT).to.equal(1000n);

      //Index is 1, that is the next token's id that is to be minted
      const count = await FlowRollNFT.read.count()
      expect(count).to.equal(1n);

      const flowRollContractAddress = await FlowRollNFT.read.flowRollContractAddresses([(count as bigint) - 1n]);

      const nr0FlowRollContract = await hre.viem.getContractAt("FlowRoll", flowRollContractAddress);

      //Checking that the contract params are set well
      const params = await nr0FlowRollContract.read.getContractParameters();
      expect(params[0]).to.equal(10); // winnerPrizeShare 10%
      expect(params[1]).to.equal(parseEther("0.01")) //DiceRollCost
      expect(params[2]).to.equal(10) // houseEdge 10%
      expect(params[3]).to.equal(parseEther("0.001")) // compensation for revealing the roll
      expect(params[4]).to.equal(1) // min 1
      expect(params[5]).to.equal(6) // max 6

      //Test the balance of the contract
      let contractBalance = await publicClient.getBalance({
        address: flowRollContractAddress
      });

      let prizeVault = await nr0FlowRollContract.read.prizeVault();

      expect(contractBalance).to.equal(prizeVault)

      //Fund the prize pool
      const fundAmount = parseEther("1")
      await nr0FlowRollContract.write.fundPrizePoolFLOW([fundAmount], { value: fundAmount });

      contractBalance = await publicClient.getBalance({
        address: flowRollContractAddress
      });

      prizeVault = await nr0FlowRollContract.read.prizeVault();

      expect(contractBalance).to.equal(prizeVault)

      expect(prizeVault).to.equal(fundAmount)

      //TODO: Test rolling the dice...
      //
    })

    //TODO: Test selling NFTs
    //TODO: Test the FlowRoll with an ERC20
    //TODO: make sure to cover all requires and test all errors
  })

});
