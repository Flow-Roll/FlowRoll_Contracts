import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { getAddress, parseGwei, parseEther, zeroAddress, formatEther, formatGwei } from "viem";

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
    it("Should all deploy, mint first NFT and test basic functionality", async function () {
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

      // Test rolling the dice...

      //Use the mock provider to set a new index for the randomness
      await MockRandProvider.write.setIndex([1]);

      //Roll the dice with 1 FLOW
      //Betting that the next dice will be 2
      await nr0FlowRollContract.write.rollDiceFLOW([2], { value: parseEther("0.01") });
      //Should pass
      //Check the prizeVault

      prizeVault = await nr0FlowRollContract.read.prizeVault();

      //It should have 1 ETH and the added dice roll cost
      expect(prizeVault).to.equal(parseEther("1.01"));
      contractBalance = await publicClient.getBalance({
        address: flowRollContractAddress
      });
      expect(contractBalance).to.equal(parseEther("1.01"));

      let lastBet = await nr0FlowRollContract.read.lastBet();
      expect(lastBet).to.equal(1n);
      let lastClosedBet = await nr0FlowRollContract.read.lastClosedBet();
      expect(lastClosedBet).to.equal(0n);

      const diceBet = await nr0FlowRollContract.read.bets([1n]);

      expect(diceBet[0]).to.equal(1n) // The request Id
      // expect(diceBet[1]).to.equal(6n) // The block number, I am not asserting in case something changes
      expect(diceBet[2].toLowerCase()).to.equal(owner.account.address.toLowerCase())
      expect(diceBet[3]).to.equal(2);
      expect(diceBet[4]).to.equal(false) // It's still open
      expect(diceBet[5]).to.equal(false) //Didn't win anything
      expect(diceBet[6]).to.equal(0) //There was no number rolled ,yet
      expect(diceBet[7]).to.equal(0n) //No payout

      //reveal the dice roll, it should be a LOSS
      await MockRandProvider.write.setRequestRandomness([1, 1]);

      //Get a contract for account2 so it can request randomness
      //@ts-ignore not cadence arch
      let account2_nr0FlowRollInteraction = await hre.viem.getContractAt("FlowRoll", flowRollContractAddress, {
        client: {
          public: account2,
          wallet: account2
        }
      })
      //The owner will get the protocol fee and the houseEdge
      let ownerETHBalance = await publicClient.getBalance({
        address: owner.account.address
      })

      //Get the balance of Account 2

      let account2Balance = await publicClient.getBalance({
        address: account2.account.address
      })

      const revealGas = await account2_nr0FlowRollInteraction.estimateGas.revealDiceRoll();

      const gasPrice = await publicClient.getGasPrice();

      const gasConsumed = revealGas * gasPrice;

      //This is how much of the reveal compensation is left after the gas payment
      const revealLeftAfterGas = parseEther("0.001") - gasConsumed;

      //@ts-ignore it should not have errors
      await account2_nr0FlowRollInteraction.write.revealDiceRoll();


      account2Balance = await publicClient.getBalance({
        address: account2.account.address
      })
      //This tests the reveal compensation
      expect(account2Balance).to.equal(parseEther("10000") + revealLeftAfterGas);

      // //Get the balance of the owner first
      let balanceBefore = ownerETHBalance

      ownerETHBalance = await publicClient.getBalance({
        address: owner.account.address
      })

      let balanceAfter = ownerETHBalance;
      //The house edge is 10% of the dice roll cost
      expect(formatEther(balanceAfter - balanceBefore)).to.equal("0.001");

      //TODO: TEST a WIN but maybe in a different IT so it doesn't get too large...

    })

    //TODO: Test selling NFTs
    //TODO: Test the FlowRoll with an ERC20
    //TODO: make sure to cover all requires and test all errors
  })

});
