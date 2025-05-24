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
    const MockFlowUSDPriceFeed = await hre.viem.deployContract("contracts/mock/MockPriceFeed.sol:MockFlowUSDPriceFeed")

    //THE FLOW/USD RATE IS SET TO 0.40494444 FLOW is 1 USD
    await MockFlowUSDPriceFeed.write.setPrice([40494444, -8]);

    const MockRandProvider = await hre.viem.deployContract("contracts/mock/MockRandProvider.sol:MockRandProvider");
    const publicClient = await hre.viem.getPublicClient();
    const SALEPRICE = 1000; //1000 USD

    const NFTSale = await hre.viem.deployContract("contracts/NFTSale.sol:NFTSale", [SALEPRICE, MockFlowUSDPriceFeed.address])

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

    //Must set the NFT contract address here on the selling contract
    await NFTSale.write.setNFTAddress([FlowRollNFT.address])

    return {
      MockRandProvider,
      MockFlowUSDPriceFeed,
      publicClient,
      owner,
      account2,
      FlowRollNFT,
      NFTSale
    }
  }

  describe("Deployment", function () {
    it("Should all deploy, mint first NFT and test basic functionality with a LOSS roll", async function () {
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
      const houseEdgeEthTaken = "0.001"
      expect(formatEther(balanceAfter - balanceBefore)).to.equal(houseEdgeEthTaken);

      prizeVault = await nr0FlowRollContract.read.prizeVault();

      contractBalance = await publicClient.getBalance({
        address: flowRollContractAddress
      });

      expect(prizeVault).to.equal(contractBalance);

      //The prizeVault should be the  the deposited 1 ETH + the dicerollCost minus the reveal compensation and minus the houseEdge that was taken from it
      const vaultShouldBe = (parseEther("1") + parseEther("0.01")) - parseEther("0.001") - parseEther(houseEdgeEthTaken)
      expect(prizeVault).to.equal(vaultShouldBe);

      //Try to reveal again and fail
      let failed = false;
      let errmsg = "";
      try {
        await account2_nr0FlowRollInteraction.write.revealDiceRoll();
      } catch (err) {
        errmsg = err.details;

        failed = true;
      }

      expect(failed).to.equal(true);
      expect(errmsg.includes("All bets are finalized")).to.be.true;
    })

    it("Should test a win with the first deployed dice roll game", async function () {
      const { MockRandProvider, NFTSale, publicClient, owner, account2, FlowRollNFT } = await loadFixture(deployFixture)

      const flowRollContractAddress = await FlowRollNFT.read.flowRollContractAddresses([0]);
      const nr0FlowRollContract = await hre.viem.getContractAt("FlowRoll", flowRollContractAddress);

      //Fund the prize pool
      const fundAmount = parseEther("1")
      await nr0FlowRollContract.write.fundPrizePoolFLOW([fundAmount], { value: fundAmount });

      //Use the mock provider to set a new index for the randomness
      await MockRandProvider.write.setIndex([1]);
      //Set the randomness index at 1 to 1
      await MockRandProvider.write.setRequestRandomness([1, 1]);

      //Roll the dice and bet on 1
      await nr0FlowRollContract.write.rollDiceFLOW([1], { value: parseEther("0.01") });

      let prizeVault = await nr0FlowRollContract.read.prizeVault();

      let contractBalance = await publicClient.getBalance({
        address: flowRollContractAddress
      });

      expect(prizeVault).to.equal(contractBalance);

      expect(contractBalance).to.equal(parseEther("1.01"))

      //Reveal and checking the gas
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

      //Now the bet was a win, the owner should have the balance + the fee

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
      //The owner gets the house edge + protocol fee , plus wins a percentage of the prize pool
      //The difference should be 10% of 1 ETH because the fees go to this account too.
      expect(formatEther(balanceAfter - balanceBefore)).to.equal("0.1");

      prizeVault = await nr0FlowRollContract.read.prizeVault();

      contractBalance = await publicClient.getBalance({
        address: flowRollContractAddress
      });

      expect(prizeVault).to.equal(contractBalance);

      expect(prizeVault).to.equal(parseEther("0.909"))

      const diceBet = await nr0FlowRollContract.read.bets([1]);
      expect(diceBet[0]).to.equal(1n); // The first request id
      expect(diceBet[2].toLowerCase()).to.equal(owner.account.address.toLowerCase()); // The player's address
      expect(diceBet[3]).to.equal(1); // The number that was bet on
      expect(diceBet[4]).to.equal(true); // closed
      expect(diceBet[5]).to.equal(true); // won
      expect(diceBet[6]).to.equal(1); // number rolled

      //10% of the 1.01 ETH,  the houseEdge which is 10% of the payout  minus the reveal compensation
      const expectedPayout = parseEther("0.101") - parseEther("0.0101") - parseEther("0.001")
      expect(diceBet[7]).to.equal(expectedPayout); // the payout is 10% of 1.01 ETH minus 10% houseFee (0.101) ,minus the reveal compensation 0.001

      //Gonna make a new bet to test the last bet incrementing
      //Use the mock provider to set a new index for the randomness
      await MockRandProvider.write.setIndex([2]);
      //Set the randomness index at 1 to 1
      await MockRandProvider.write.setRequestRandomness([2, 2]);
      //Roll the dice and bet on 1 again
      await nr0FlowRollContract.write.rollDiceFLOW([1], { value: parseEther("0.01") });

      const lastBet = await nr0FlowRollContract.read.lastBet();
      const lastClosedBet = await nr0FlowRollContract.read.lastClosedBet();

      expect(lastBet).to.equal(2n);
      expect(lastClosedBet).to.equal(1n);

      //the bets have successfully incremented. yay

    })

    it("Test Oracle price feed.", async function () {
      const { NFTSale, publicClient, owner, account2, MockFlowUSDPriceFeed } = await loadFixture(deployFixture);

      const priceFeed = await MockFlowUSDPriceFeed.read.getPrice();
      expect(priceFeed[0]).to.equal(40494444n)
      expect(priceFeed[1]).to.equal(-8);

      const USDPriceInFLow = await NFTSale.read.getUSDPriceInFlow();
      expect(USDPriceInFLow).to.equal(parseEther("0.40494444"));
      const expectedPriceInFlow = await NFTSale.read.getExpectedPriceInFlow();
      expect(expectedPriceInFlow).to.equal(parseEther("2469"));

    })

    it("Test coupons and selling NFTs", async function () {
      const { NFTSale, publicClient, owner, account2, MockFlowUSDPriceFeed, FlowRollNFT } = await loadFixture(deployFixture);

      //It should create coupon codes with different prices
      const COUPON1 = "#GOWITHTHEFLOW"
      const COUPON1ComissionAddress = account2.account.address;
      const COUPON1PercentageOff = 10; // 10% off
      const COUPON1Comission = 10; //10% comission
      const COUPON1CouponUsesLeft = 2; // Only creating 2 coupons

      await NFTSale.write.setCoupon(
        [COUPON1,
          COUPON1ComissionAddress,
          COUPON1PercentageOff,
          COUPON1Comission,
          COUPON1CouponUsesLeft]
      );

      const couponParameters = await NFTSale.read.getCoupon([COUPON1]);
      expect(couponParameters[0].toLowerCase()).to.equal(COUPON1ComissionAddress.toLowerCase())
      expect(couponParameters[1]).to.equal(COUPON1PercentageOff)
      expect(couponParameters[2]).to.equal(COUPON1Comission)
      expect(couponParameters[3]).to.equal(COUPON1CouponUsesLeft)

      const usedCuponAlready = await NFTSale.read.usedCouponAlready([COUPON1ComissionAddress, COUPON1])

      expect(usedCuponAlready).to.equal(false);

      //The sale price with the coupons should be calculated correctly
      const fullPriceInFlow = await NFTSale.read.getExpectedPriceInFlow();
      expect(fullPriceInFlow).to.equal(parseEther("2469"))
      const reducedPrice = await NFTSale.read.getReducedPrice([COUPON1, fullPriceInFlow]);
      expect(reducedPrice).to.equal(parseEther("2222.1"))
      //The purchase should mint an NFT and it should have the dice game contracts
      const comission = await NFTSale.read.getComission([reducedPrice, COUPON1])
      expect(comission).to.equal(parseEther("222.21"));

      //Gonna buy an NFT and sends the correct amount of value.
      //NOT GONNA USE COUPON, NO ERC20 either
      const winnerprizeShare = 10;
      const diceRollCost = parseEther("0.1")
      const houseEdge = 10;
      const revealCompensation = parseEther("0.01")

      //TODO: I need to check that the value was transferred correctly. 
      //Maybe I connect a different signer to the contract
      await NFTSale.write.buyNFT([
        "",
        account2.account.address,
        zeroAddress,
        winnerprizeShare,
        diceRollCost,
        houseEdge,
        revealCompensation,
        1,
        5
      ],
        {
          value: parseEther("2469")
        });

      // verify the account2 got the NFT
      const balanceOfAccount2 = await FlowRollNFT.read.balanceOf([account2.account.address])
      expect(balanceOfAccount2).to.equal(1n);
      const count = await FlowRollNFT.read.count();
      expect(count).to.equal(2n);
      const contractAddress = await FlowRollNFT.read.flowRollContractAddresses([1n]);

      let account2_nr0FlowRollInteraction = await hre.viem.getContractAt("FlowRoll", contractAddress, {
        client: {
          public: account2,
          wallet: account2
        }
      })
      const contractParameters = await account2_nr0FlowRollInteraction.read.getContractParameters();
      expect(contractParameters[0]).to.equal(winnerprizeShare)
      expect(contractParameters[1]).to.equal(diceRollCost)
      expect(contractParameters[2]).to.equal(houseEdge)
      expect(contractParameters[3]).to.equal(revealCompensation)
      expect(contractParameters[4]).to.equal(1)
      expect(contractParameters[5]).to.equal(5)

      let errorOccured = false
      let errorMessage = ""
      try {
        await NFTSale.write.buyNFT([
          "",
          account2.account.address,
          zeroAddress,
          winnerprizeShare,
          diceRollCost,
          houseEdge,
          revealCompensation,
          1,
          5
        ],
          {
            value: parseEther("2469")
          });

      } catch (err) {
        errorOccured = true;
        errorMessage = err.details;
      }
      expect(errorOccured).to.equal(true);
      expect(errorMessage.includes("Duplicate parameters")).to.equal(true)

      //Now I'm gonna mint one with the coupon
      await NFTSale.write.buyNFT([
        COUPON1,
        account2.account.address,
        zeroAddress,
        winnerprizeShare,
        diceRollCost,
        houseEdge,
        revealCompensation,
        3,
        5
      ],
        {
          value: reducedPrice
        });

      //TODO: check that the payments have been transferred to the correct address

      //TODO: check that the commission has been paid correctly!!

    })

    it("Test FlowRoll with an ERC20", async function () {
      const ERC20 = await hre.viem.deployContract("MockERC20", [parseEther("1000000")])
      //  Mint a flow roll NFT with an ERC20 token and test betting and payouts
    })


    it("Cover remaining error cases", async function () { })
  })

});
