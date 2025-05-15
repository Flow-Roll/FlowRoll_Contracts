import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FlowRoll.sol";

contract FlowRollNft is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable {
    uint256 public MAXMINT; //Maximum amount of NFTs that can be minted
    uint256 public index; //Custom index to associate minted tokens with contract addresses

    mapping(uint256 => address) flowRollContractAddresses;

    uint256 private price;

    mapping(bytes32 => bool) parametersExist;

    event NewFlowRoll(address indexed owner);

    constructor(
        _price,
        //These are the mint parameters in the constructor
        address to,
        address ERC20Address,
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) ERC721("FlowRollNFT", "FRL") {
        price = _price;
        index = 0;
        MAXMINT = 1000; //hard coding a maximum of 1000 NFTs here
        mint(
            to,
            ERC20Address,
            winnerPrizeShare,
            diceRollCost,
            houseEdge,
            revealCompensation,
            min,
            max
        );
    }

    //The owner of the contract can update the mint price
    function updatePrice(uint256 newPrice) external onlyOwner {
        price = newPrice;
    }

    //TODO: Craete the base URI when I know the domain name for the project...
    function _baseURI() internal pure override returns (string memory) {
        return "TODO:uri";
    }

    function mint(
        address to,
        address ERC20Address, //THe ERC20Address parameter if 0 means the game is played for flow, else the specific ERC20 token
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) payable {
        require(totalSupply() <= MAXMINT); //Can't mint more than max mint!
        require(msg.value == price, "Invalid mint price");
        require(min < max, "min must be < than max");
        bytes32 parametersHash = hashRollParameters(
            ERC20Address,
            winnerPrizeShare,
            diceRollCost,
            houseEdge,
            revealCompensation,
            min,
            max
        );
        // Check that an NFT with the parameters exists already, do not allow two to have the same parameters
        require(!parametersExist[parametersHash], "Duplicate parameters");
        parametersExist[parametersHash] = true;

        FlowRoll _flowRoll = new FlowRoll(
            index,
            ERC20Address,
            winnerPrizeShare,
            diceRollCost,
            houseEdge,
            revealCompensation,
            min,
            max
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

    function hashRollParameters(
        address ERC20Address,
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) internal returns (byes32) {
        return
            keccak256(
                abi.encodePacked(
                    ERC20Address,
                    winnerPrizeShare,
                    diceRollCost,
                    houseEdge,
                    revealCompensation,
                    min,
                    max
                )
            );
    }
}
