// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CadenceRandomConsumer} from "@onflow/flow-sol-utils/src/random/CadenceRandomConsumer.sol";


//The flow roll contract is a dice game created with flow on chain randomness

struct DiceBets{
    uint256 requestId, //The requestId for the randoness
    uint256 player, //The address that is betting 
    uint8 bet, //The number to bet on
    bool closed,
    bool won,
    bool numberRolled,
    uint256 payout,
    uint256 newPrizePool
}

contract FlowRoll is CadenceRandomConsumer {

    address private ERC721Address;
    uint256 private ERC721Index;

    uint256 private prizeVault;

    address private ERC20Address;

    //The percentage share of the prize for the winner
    uint8 winnerPrizeShare;

    uint256 diceRollCost;

    //The percentage of the deposits transferred to the winner
    uint8 houseEdge; //This is a percentage, taken from the loss and the win.

    //The compensation paid for revealing the winning numbers
    //This is specified in flat rate of the deposit, not percentage
    uint256 revealCompensation;

    //The index of the last bet placed
    uint256 lastBet; 
    
    //The last closed bet, the bets must be closed in order for fairness.
    uint256 lastClosedBet;

    // The bets stored in a mapping in order
    mapping(uint256 => DiceBets) bets;

    uint8 min;
    uint8 max;


    //Event emitted when a bet is placed
    event RollPlaced(
        address player,
        uint8 bet,
        uint256 prizePool
    );

    //Event emitted when a roll is completed
    event RollResult(
        address player,
        bool won,
        uint8 numberRolled,
        uint256 payout,
        uint256 newPrizePool
    );

    event PrizePoolFunded(uint256 amount);
    
    //Once the roll parameters are created the can't be changed, to have a new FlowRoll, somebody needs to buy a new NFT
    constructor(
        uint256 _ERC2721Index,
        address _ERC20Address,
        uint8 _winnerPrizeShare,
        uint256 _diceRollCost,
        uint8 _houseEdge,
        uint8 _revealCompensation,
        uint8 _min,
        uint8 _max
    ) {
        require(_winnerPrizeShare <= 100, "Prize share is 100% max");
        require(_houseEdge <= 100, "House edge is 100% max");
        require(_revealCompensation < _diceRollCost,"");
        ERC721Address = msg.sender;
        ERC721Index = _ERC721Index;
        prizeVault = 0;
        //Sets if the dice rolls are played for ERC20 tokens or not. 0 address would be FLOW and a specified address would be ERC20
        ERC20Address = _ERC20Address;
        diceRollCost = _diceRollCost;
        houseEdge = _houseEdge;
        revealCompensation = _revealCompensation;
        lastBet = 0;
        lastClosedBet = 0;
        min = _min;
        max = _max;

        //TODO: reveal compensation must be less than the diceRollCost
        //TODO: revealCompensation and house edge must be less than the diceRollCost together
    }

    //The admin of the FlowRoll contract is always the owner of the NFT that minted it
    function getAdmin() internal view returns (address) {
        return IERC721(ERC721Address).ownerOf(ERC721Index);
    }

    function fundPrizePoolFLOW(uint256 amount) external payable {
        require(ERC20Address == address(0), "Can't fund the pool");
        require(amount == msg.value, "Invalid deposit amount");
        prizeVault += amount;
        emit PrizePoolFunded(amount);
    }

    //Funding requires an approval
    function fundPrizePoolERC20(uint256 amount) external {
        require(ERC20Address != address(0), "Can't fund the pool");
        IERC20(ERC20Address).transferFrom(msg.sender, address(this), amount);
        prizeVault += amount;
        emit PrizePoolFunded(amount);
    }

    function rollDiceFLOW(uint8 bet) external payable{
      require(msg.value == diceRollCost,"Invalid value sent");
      require(ERC20Address == address(0),"Only FLow");\
      checkBet(bet, 1,6); // The dice rolled is between 1 - 6 //TODO: This could be later configurable
      //Add the flow to the winnerPrizeShare
      prizeVault += diceRollCost;
      //Create a new randomness request
      uint256 requestId = _requestRandomness();
      //Increment the last bet indexes
      lastBet +=1;
      bets[lastBet] = Bet(
        requestId,
        msg.sender,
        bet,
        false, //closed
        false, //Not won yet,
        0, // Didn't roll a number yet,
        0, // No payout,
        prizeVault // The current prize pool
      );
      
      emit RollPlaced(msg.sender, bet, prizeVault);
    }

    function rollDiceERC20(uint256 betAmount, uint8 bet) external{
      require(betAmount == diceRollCost,"Invalid ");
      require(ERC20Address != address(0),"Must use Flow");
      checkBet(bet, 1,6);
      IERC20(ERC20Address).transferFrom(msg.sender, address(this), betAmount);
      prizeVault += amount;
      uint256 requrestId = _requestRandomness();
      lastBet += 1;
      bets[lastBet] = Bet(
        requestId,
        msg.sender,
        bet,
        false,
        false,
        0,
        0,
        prizeVault
      );
      emit RollPlaced(msg.sender, bet, prizeVault);
    }

//https://github.com/onflow/random-coin-toss/blob/main/solidity/src/CoinToss.sol
    function revealDiceRoll() external{
      require(lastBet  > lastClosedBet,"All bets are closed");
      DiceBets betToClose = bets[lastClosedBet];

      uint8 rolledRandomNumber = uint8(_fulfillRandomInRange(betToClose.requestId,min,max));\

      //Determine if the bet we closing did win
      if(betToClose.bet == rolledRandomNumber){
        //WIN
        // Now close the bet
        //Transfer the prize
        //Transfer the payouts to the house and the reveal compensation
      } else {
        //LOSS
        //Close the bet
        //Transfer the payouts to the house and the reveal compensation
      }

      //Transfer the payouts, pay the feess
    }

    function checkBet(uint8 bet,) internal{
        require(bet >= min, "Bet must be >= min");
        require(bet <= max,"Bet must be <= max");
    }

}
