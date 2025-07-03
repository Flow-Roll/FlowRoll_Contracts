// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface IFlowRollNFT {
    function mintFlowRoll(
        address to,
        address ERC20Address,
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint16[3] memory betParams
    ) external;
}

interface IPriceFeed {
    function getPrice() external view returns (int64, int32);

    function getEWMAPrice(
        uint256 mantissa,
        uint256 exponent
    ) external pure returns (uint256);
}

contract NFTSale is Ownable {
    using Address for address payable;
    address payable private payee;

    uint256 private USDcost;

    int32 private expectedExpo;
    uint8 private usedExpo;

    address private NFT;

    address private priceFeedContract;

    //The address that gets commission from a coupon payment
    mapping(string => address) private couponcommissionAddresses;
    //The coupon percentage off is what the buyer gets off from the price
    mapping(string => uint8) private couponPercentageOff;
    //commission is the percentage of commission transferred from the paid value
    mapping(string => uint8) private couponcommission;
    //The amount of uses left from a coupon
    mapping(string => uint8) private couponUsesLeft;
    //Did the address already use that coupon? Only one per address
    mapping(address => mapping(string => bool)) private addressUsedCoupon;


    uint32 public freeMint;

    constructor(
        uint256 _USDcost,
        address _priceFeedContract
    ) Ownable(msg.sender) {
        USDcost = _USDcost;
        payee = payable(msg.sender);
        require(_priceFeedContract != address(0), "Price feed must be set");
        priceFeedContract = _priceFeedContract;
        expectedExpo = -8;
        usedExpo = 8;
        freeMint = 1000;
    }

    function setNFTAddress(address to) external onlyOwner {
        NFT = to;
    }

    function setUSDcost(uint256 to) external onlyOwner {
        USDcost = to;
    }

    //A function to help with recovery if for some reason the Pyth oracle contract changes the expo
    //It should never be used but it's an onlyowner function just in case it's needed
    function setExpo(int32 _expectedExpo, uint8 _usedExpo) external onlyOwner {
        expectedExpo = _expectedExpo;
        usedExpo = _usedExpo;
    }

    function setCoupon(
        string calldata coupon,
        address recipient,
        uint8 percentageOff,
        uint8 commission,
        uint8 _couponUsesLeft
    ) external onlyOwner {
        require(recipient != address(0), "invalid recipient");
        couponcommissionAddresses[coupon] = recipient;
        couponPercentageOff[coupon] = percentageOff;
        couponcommission[coupon] = commission;
        couponUsesLeft[coupon] = _couponUsesLeft;
    }

    function getCoupon(
        string calldata coupon
    ) external view returns (address, uint8, uint8, uint8) {
        return (
            couponcommissionAddresses[coupon],
            couponPercentageOff[coupon],
            couponcommission[coupon],
            couponUsesLeft[coupon]
        );
    }

    function usedCouponAlready(
        address addr,
        string calldata coupon
    ) external view returns (bool) {
        return addressUsedCoupon[addr][coupon];
    }

    function buyNFT(
        string calldata coupon,
        address to,
        address ERC20Address, //THe ERC20Address parameter if 0 means the game is played for flow, else the specific ERC20 token
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint16[3] memory betParams
    ) external payable {
        if (bytes(coupon).length != 0) {
            //Check if the coupon is valid and if not then revert
            require(
                couponcommissionAddresses[coupon] != address(0),
                "Invalid coupon"
            );
            require(couponUsesLeft[coupon] != 0, "Coupon was used up");
            require(
                addressUsedCoupon[msg.sender][coupon] == false,
                "Address already used coupon"
            );
            //Substract a use from a coupon
            couponUsesLeft[coupon] -= 1;
            addressUsedCoupon[msg.sender][coupon] = true;

            uint256 flowPrice = getExpectedPriceInFlow();
            //Calculate the percentage off
            uint256 newPrice = getReducedPrice(coupon, flowPrice);
            require(newPrice == msg.value, "Invalid price with coupon");
            uint256 commission = getcommission(newPrice, coupon);
            //The sale profit is newPrice minus the commission
            uint256 profit = newPrice - commission;
            Address.sendValue(payee, profit);
            //Forward the payments
            Address.sendValue(
                payable(couponcommissionAddresses[coupon]),
                commission
            );
        } else {
            require(msg.value == getExpectedPriceInFlow(), "Invalid price");
            Address.sendValue(payee, msg.value);
        }

        IFlowRollNFT(NFT).mintFlowRoll(
            to,
            ERC20Address,
            winnerPrizeShare,
            diceRollCost,
            houseEdge,
            revealCompensation,
            betParams
        );
    }

    //This function is used both internally and externally, a view function to get the flow price from the oraclie price feed
    function getUSDPriceInFlow() public view returns (uint256) {
        (int64 mantissa, int32 expo) = IPriceFeed(priceFeedContract).getPrice();

        require(expo == expectedExpo, "The exponentiation is unexpected");
        return
            IPriceFeed(priceFeedContract).getEWMAPrice(
                uint256(uint64(mantissa)),
                usedExpo
            );
    }

    //This function is used to get the expected price in flow
    function getExpectedPriceInFlow() public view returns (uint256) {
        return ((USDcost * 1e18) / getUSDPriceInFlow()) * 1e18;
    }

    function getReducedPrice(
        string calldata coupon,
        uint256 flowPrice
    ) public view returns (uint256) {
        uint256 subFromPrice = (flowPrice / 100) * couponPercentageOff[coupon];
        return flowPrice - subFromPrice;
    }

    function getcommission(
        uint256 newPrice,
        string calldata coupon
    ) public view returns (uint256) {
        return (newPrice / 100) * couponcommission[coupon];
    }

    function namehasher() external returns (bytes32) {}
}
