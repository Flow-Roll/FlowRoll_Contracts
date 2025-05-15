// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {CadenceRandomConsumer} from "@onflow/flow-sol-utils/src/random/CadenceRandomConsumer.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


//The flow roll contract is a dice game created with flow on chain randomness

struct DiceBets{
    uint256 requestId, //The requestId for the randoness
    uint256 player, //The address that is betting 
    uint8 bet, //The number to bet on
    bool closed,
    bool won,
    bool numberRolled,
    uint256 payout,
}

contract FlowRoll is CadenceRandomConsumer {
    using SafeMath for uint256;
    using Address for address payable;
    using SafeERC20 for IERC20;

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
        require(_revealCompensation < _diceRollCost,"Reveal compensation too high");
        // revealCompensation plus houseEdge (taken from the diceRollCost) must be less than the diceRollCost 
        require(_revealCompensation + calculateHouseEdge(_diceRollCost,_houseEdge) < _diceRollCost,"invalid House edge or revealCompensation");

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
      );
      emit RollPlaced(msg.sender, bet, prizeVault);
    }

//https://github.com/onflow/random-coin-toss/blob/main/solidity/src/CoinToss.sol
    function revealDiceRoll() external{
      require(lastBet  > lastClosedBet,"All bets are closed");
      uint8 rolledRandomNumber = uint8(_fulfillRandomInRange(bets[lastClosedBet].requestId,min,max));\

      //Determine if the bet we closing did win
      if(bets[lastClosedBet].bet == rolledRandomNumber){
        //WIN
        // Now close the bet
        bets[lastClosedBet].closed = true;
        bets[lastClosedBet].won = true;
        (uint256 vaultShare, uint256 housePayment) = calculateWinnerPayoutWithFees();
        bets[lastClosedBet].payout = vaultShare;
        //Transfer the prize, the fee to the house and the reveal compensation
        _transferWin(vaultShare,housePayment, bets[lastClosedBet].player);
        emit RollResult(bets[lastClosedBet].player,true, rolledRandomNumber,vaultShare, prizeVault);
      } else {
        //LOSS
        //Close the bet
        bets[lastClosedBet].closed = true;
        bets[lastClosedBet].won = false;
        bets[lastClosedBet].payout = 0;
        //Transfer the payouts to the house and the reveal compensation
        _transferLossFees(diceRollCost);
        emit RollResult(bets[lastClosedBet].player, false,rolledRandomNumber, 0,prizeVault);
      }
          }
     
     //Transfer fees will send the fees from the winner and loser bets
     //The feeFrom argument is either the diceRollCost for losers or taken from the winnerPrizeShare percentage calculation
     function _transferLossFees(uint256 feeFrom) internal {
       uint256 housePayment = calculateHouseEdge(feeFrom);
       address houseAddress = getAdmin();
       if(ERC20Address == address(0)){
           payable(houseAddress).sendValue(housePayment);
           //Sends the compensation to the address that revealed the dice roll
           payable(msg.sender).sendValue(revealCompensation);    
       } else {
         IERC20(ERC20Address).transfer(houseAddress,housePayment);
         IERC20(ERC20Address).transfer(msg.sender,revealCompensation);
       }
       //Update the prize pool
       prizeVault -= (housePayment + revealCompensation);
     }

     function _transferWin(uint256 payout, uint256 housePayment, address winnerAddress) internal {
      address houseAddress = getAdmin();
      if (ERC20Address == address(0)){
        payable(houseAddress).sendValue(housePayment);
        payable(msg.sender).sendValue(revealCompensation);
        payable(winnerAddress).sendValue(payout);
      } else {
        IERC20(ERC20Address).transfer(houseAdress, housePayment);
        IERC20(ERC20Address).transfer(msg.sender,revealCompensation);
        IERC20(ERC20Address).transfer(winnerAddress,payout);
      }
      prizeVault -= (housePayment + revealCompensation + payout);
     }


    function checkBet(uint8 bet) internal{
        require(bet >= min, "Bet must be >= min");
        require(bet <= max,"Bet must be <= max");
    }

    function calculateHouseEdge(uint256 _of) internal view returns (uint256){
      return (_of / 100) * houseEdge;
    }

    function calculateWinnerPrizeShare(uint256 _of) internal view returns (uint256){
      return (_of / 100) * winnerPrizeShare;
    }

    function calculateWinnerPayoutWithFees() internal view returns (uint256, uint256) {
      //The winner gets the diceRollCost back + the percentage of the winner prize share minus the fees...
      uint256 prizeVaultShareWithoutFees = calculateWinnerPrizeShare(prizeVault);
      uint256 houseEdge = calculateHouseEdge(prizeVaultShareWithoutFees);
      uint256 vaultShare = (prizeVaultShareWithoutFees - houseEdge) - revealCompensation;

      //Returns the amount to send to the winner, the house edge
      return vaultShare, houseEdge

    }

}
