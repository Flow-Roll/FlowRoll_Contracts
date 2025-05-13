import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FlowRoll.sol";

contract FlowRollNft is ERC721, ERC721URIStorage, Ownable {
    uint256 public index;

    mapping(uint256 => address) flowRollContractAddresses;

    uint256 private price;

    event NewFlowRoll(address indexed owner); //TODO: add the parameters of the flow roll

    constructor(_price) ERC721("FlowRollNFT", "FRL") {
        price = _price;
        index = 0;
    }

    function _baseURI() internal pure override returns (string memory) {
        return "TODO:uri";
    }

    //THe ERC20Address parameter if 0 means the game is played for flow, else the specific ERC20 token
    function mint(
        address to, 
        address ERC20Address,
        uint8 winnerPrizeShare, 
        uint256 diceRollCost, 
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
        ) payable {
        require(msg.value == price, "Invalid mint price");
        require(min < max, "min must be < than max");
        FlowRoll _flowRoll = new FlowRoll(
            index, 
            ERC20Address, 
            winnerPrizeShare, 
            diceRollCost, 
            houseEdge,
            revealCompensation,
            min, max
            );

        flowRollContractAddresses[index] = address(_flowRoll);

        _safeMint(to, index);
        _setTokenURI(index, index); //The URI is the index, it will be accessed by index

        index = index + 1;

        emit NewFlowRoll(msg.sender);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
