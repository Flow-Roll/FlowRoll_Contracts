import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FlowRoll.sol";

contract FlowRollNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 public MAXMINT; //Maximum amount of NFTs that can be minted
    uint256 public count; //Custom count to associate minted tokens with contract addresses

    mapping(uint256 => address) public flowRollContractAddresses;

    address private nftSale;

    mapping(bytes32 => bool) parametersExist;

    event NewFlowRoll(address indexed owner);

    address private randProvider;

    uint8 public protocolFee; // It's a percentage fee, taken from the houseEdge

    constructor(
        address _randProvider,
        address _nftSale,
        //These are the mint parameters in the constructor
        address to,
        address ERC20Address,
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) ERC721("FlowRollNFT", "FRL") Ownable(msg.sender) {
        nftSale = _nftSale;
        count = 0;
        MAXMINT = 1000; //hard coding a maximum of 1000 NFTs here
        randProvider = _randProvider; // The randomness provider address
        _flowRollMinter(
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

    function _flowRollMinter(
        address to,
        address ERC20Address, //THe ERC20Address parameter if 0 means the game is played for flow, else the specific ERC20 token
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) internal {
        require(count < MAXMINT); //Can't mint more than max mint!

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
            randProvider,
            count,
            ERC20Address,
            winnerPrizeShare,
            diceRollCost,
            houseEdge,
            revealCompensation,
            min,
            max
        );

        flowRollContractAddresses[count] = address(_flowRoll);

        _safeMint(to, count);
        //TODO: check if I need this:
        // _setTokenURI(count, _tokenURIs); //The URI is the count, it will be accessed by count

        count = count + 1;

        emit NewFlowRoll(msg.sender);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://flowroll.club/";
    }

    function mintFlowRoll(
        address to,
        address ERC20Address, //THe ERC20Address parameter if 0 means the game is played for flow, else the specific ERC20 token
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) external {
        require(msg.sender == nftSale, "Only selling contract");
        _flowRollMinter(
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

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    //Use this on the front end to check the parameters
    function hashRollParameters(
        address ERC20Address,
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) public pure returns (bytes32) {
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    //The owner of the NFT contract can change the protocol fee, it's maximum 20%
    function setProtocolFee(uint8 to) external onlyOwner {
        require(to <= 20, "20 max");
        protocolFee = to;
    }

    //This is an administrative function that allows changing the NFT sale contract, in case something goes wrong with it.
    function changeNFTSaleContract(address to) external onlyOwner {
        nftSale = to;
    }
}
