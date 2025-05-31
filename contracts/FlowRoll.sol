// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./RandProvider.sol";

//The flow roll contract is a dice game created with flow on chain randomness
struct DiceBets {
    uint256 requestId; //The requestId for the randoness
    uint256 createdAtBlock;
    address player; //The address that is betting
    uint8 bet; //The number to bet on
    bool closed;
    bool won;
    uint8 numberRolled;
    uint256 payout;
}

interface IProtocolFeeProvider {
    function protocolFee() external view returns (uint8);

    function owner() external view returns (address);
}

contract FlowRoll {
    using Address for address payable;
    using SafeERC20 for IERC20;

    RandProvider private randProvider;

    address private ERC721Address;
    uint256 public ERC721Index;

    uint256 public prizeVault;

    address public ERC20Address;

    //The percentage share of the prize for the winner
    uint8 winnerPrizeShare;

    uint256 diceRollCost;

    //The percentage of the deposits transferred to the winner
    uint8 houseEdge; //This is a percentage, taken from the loss and the win.

    //The compensation paid for revealing the winning numbers
    //This is specified in flat rate of the deposit, not percentage
    uint256 revealCompensation;

    //The index of the last bet placed
    uint256 public lastBet;

    //The last closed bet, the bets must be closed in order for fairness.
    uint256 public lastClosedBet;

    // The bets stored in a mapping in order
    mapping(uint256 => DiceBets) public bets;

    uint16 min;
    uint16 max;

    //Event emitted when a bet is placed
    event RollPlaced(address player, uint8 bet, uint256 prizePool);

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
        address _randProvider,
        uint256 _ERC721Index,
        address _ERC20Address,
        uint8 _winnerPrizeShare,
        uint256 _diceRollCost,
        uint8 _houseEdge,
        uint256 _revealCompensation,
        uint16 _min,
        uint16 _max
    ) {
        require(_winnerPrizeShare <= 100, "Prize share is 100% max");
        require(_houseEdge <= 100, "House edge is 100% max");
        require(
            _revealCompensation < _diceRollCost,
            "Reveal compensation too high"
        );
        // revealCompensation plus houseEdge (taken from the diceRollCost) must be less than the diceRollCost
        require(
            _revealCompensation + calculateHouseEdge(_diceRollCost) <
                _diceRollCost,
            "invalid House edge or revealCompensation"
        );

        randProvider = RandProvider(_randProvider);

        ERC721Address = msg.sender;
        ERC721Index = _ERC721Index;
        prizeVault = 0;
        //Sets if the dice rolls are played for ERC20 tokens or not. 0 address would be FLOW and a specified address would be ERC20
        ERC20Address = _ERC20Address;
        winnerPrizeShare = _winnerPrizeShare;
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

    //The protocol fee percentage as fetched from the NFT contract
    function getProtocolFee() internal view returns (uint8) {
        return IProtocolFeeProvider(ERC721Address).protocolFee();
    }

    //The owner of the protocol fee
    function protocolFeeOwner() internal view returns (address) {
        return IProtocolFeeProvider(ERC721Address).owner();
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

    function rollDiceFLOW(uint8 bet) external payable {
        require(msg.value == diceRollCost, "Invalid value sent");
        require(ERC20Address == address(0), "Only FLow");
        checkBet(bet); // Check that the bet is between min and max
        //Add the flow to the winnerPrizeShare
        prizeVault += diceRollCost;
        //Create a new randomness request
        uint256 requestId = randProvider.getRandomnessRequestId();
        //Increment the last bet indexes
        lastBet += 1;
        bets[lastBet] = DiceBets(
            requestId,
            block.number,
            msg.sender,
            bet,
            false, //closed
            false, //Not won yet,
            0, // Didn't roll a number yet,
            0 // No payout,
        );

        emit RollPlaced(msg.sender, bet, prizeVault);
    }

    function rollDiceERC20(uint256 betAmount, uint8 bet) external {
        require(betAmount == diceRollCost, "Invalid ");
        require(ERC20Address != address(0), "Must use Flow");
        checkBet(bet);
        IERC20(ERC20Address).transferFrom(msg.sender, address(this), betAmount);
        prizeVault += betAmount;
        uint256 requestId = randProvider.getRandomnessRequestId();
        lastBet += 1;
        bets[lastBet] = DiceBets(
            requestId,
            block.number,
            msg.sender,
            bet,
            false,
            false,
            0,
            0
        );
        emit RollPlaced(msg.sender, bet, prizeVault);
    }

    function revealDiceRoll() external {
        require(lastBet > lastClosedBet, "All bets are finalized");
        lastClosedBet++;
        require(
            block.number > bets[lastClosedBet].createdAtBlock,
            "Can't roll and reveal in the same block"
        );
        uint8 rolledRandomNumber = uint8(
            randProvider.fulfillRandomnessRequest(
                bets[lastClosedBet].requestId,
                min,
                max
            )
        );

        //Determine if the bet we closing did win
        if (bets[lastClosedBet].bet == rolledRandomNumber) {
            //WIN
            // Now close the bet
            bets[lastClosedBet].closed = true;
            bets[lastClosedBet].won = true;
            bets[lastClosedBet].numberRolled = rolledRandomNumber;
            (
                uint256 vaultShare,
                uint256 housePaymentWithoutProtocolFee
            ) = calculateWinnerPayoutWithFees();
            bets[lastClosedBet].payout = vaultShare;
            //Transfer the prize, the fee to the house and the reveal compensation
            _transferWin(
                vaultShare,
                housePaymentWithoutProtocolFee,
                bets[lastClosedBet].player
            );
            emit RollResult(
                bets[lastClosedBet].player,
                true,
                rolledRandomNumber,
                vaultShare,
                prizeVault
            );
        } else {
            //LOSS
            //Close the bet
            bets[lastClosedBet].closed = true;
            bets[lastClosedBet].won = false;
            bets[lastClosedBet].payout = 0;
            bets[lastClosedBet].numberRolled = rolledRandomNumber;
            //Transfer the payouts to the house and the reveal compensation
            _transferLossFees(diceRollCost);
            emit RollResult(
                bets[lastClosedBet].player,
                false,
                rolledRandomNumber,
                0,
                prizeVault
            );
        }
    }

    //Transfer fees will send the fees from the winner and loser bets
    //The feeFrom argument is either the diceRollCost for losers or taken from the winnerPrizeShare percentage calculation
    function _transferLossFees(uint256 feeFrom) internal {
        //The house payment is what the owner of the NFT gets
        //There is a protocol fee associated with all housePayments
        uint256 housePaymentWithoutFee = calculateHouseEdge(feeFrom);
        uint256 protocolFee = calculateProtocolFee(housePaymentWithoutFee);
        uint256 housePayment = housePaymentWithoutFee - protocolFee;
        address houseAddress = getAdmin();
        if (ERC20Address == address(0)) {
            payable(houseAddress).sendValue(housePayment);
            payable(getProtocolFeeOwner()).sendValue(protocolFee);
            //Sends the compensation to the address that revealed the dice roll
            payable(msg.sender).sendValue(revealCompensation);
        } else {
            IERC20(ERC20Address).transfer(houseAddress, housePayment);
            IERC20(ERC20Address).transfer(getProtocolFeeOwner(), protocolFee);
            IERC20(ERC20Address).transfer(msg.sender, revealCompensation);
        }
        //Update the prize pool
        prizeVault -= (housePaymentWithoutFee + revealCompensation);
    }

    function _transferWin(
        uint256 payout,
        uint256 housePaymentWithoutProtocolFee,
        address winnerAddress
    ) internal {
        uint256 protocolFee = calculateProtocolFee(
            housePaymentWithoutProtocolFee
        );
        uint256 housePayment = housePaymentWithoutProtocolFee - protocolFee;
        address houseAddress = getAdmin();
        if (ERC20Address == address(0)) {
            payable(getProtocolFeeOwner()).sendValue(protocolFee);
            payable(houseAddress).sendValue(housePayment);
            payable(msg.sender).sendValue(revealCompensation);
            payable(winnerAddress).sendValue(payout);
        } else {
            IERC20(ERC20Address).transfer(getProtocolFeeOwner(), protocolFee);
            IERC20(ERC20Address).transfer(houseAddress, housePayment);
            IERC20(ERC20Address).transfer(msg.sender, revealCompensation);
            IERC20(ERC20Address).transfer(winnerAddress, payout);
        }
        prizeVault -= (housePaymentWithoutProtocolFee +
            revealCompensation +
            payout);
    }

    function checkBet(uint16 bet) internal {
        require(bet >= min, "Bet must be >= min");
        require(bet <= max, "Bet must be <= max");
    }

    function calculateHouseEdge(uint256 _of) internal view returns (uint256) {
        return (_of / 100) * houseEdge;
    }

    //The protocol fee is a fee on the House.
    function calculateProtocolFee(
        uint256 _houseEdgeFee
    ) internal view returns (uint256) {
        return
            (_houseEdgeFee / 100) *
            IProtocolFeeProvider(ERC721Address).protocolFee();
    }

    function calculateWinnerPrizeShare(
        uint256 _of
    ) internal view returns (uint256) {
        return (_of / 100) * winnerPrizeShare;
    }

    function calculateWinnerPayoutWithFees()
        internal
        view
        returns (uint256, uint256)
    {
        //The winner gets the diceRollCost back + the percentage of the winner prize share minus the fees...
        uint256 prizeVaultShareWithoutFees = calculateWinnerPrizeShare(
            prizeVault
        );
        uint256 _houseEdge = calculateHouseEdge(prizeVaultShareWithoutFees);
        uint256 vaultShare = (prizeVaultShareWithoutFees - _houseEdge) -
            revealCompensation;

        //aReturns the amount to send to the winner, the house edge
        return (vaultShare, _houseEdge);
    }

    //Get contract parameters returns winnerPrizeShare,diceRollCost,houseEdge,revealCompensation,min,max
    function getContractParameters()
        external
        view
        returns (uint8, uint256, uint8, uint256, uint16, uint16)
    {
        return (
            winnerPrizeShare,
            diceRollCost,
            houseEdge,
            revealCompensation,
            min,
            max
        );
    }

    function getProtocolFeeOwner() internal view returns (address) {
        return IProtocolFeeProvider(ERC721Address).owner();
    }
}
