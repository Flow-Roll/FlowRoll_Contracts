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
        uint16[3] memory betParams,
        string memory name
    ) external;
}

contract NFTSale_v2 is Ownable {
    using Address for address payable;
    address payable private payee;

    uint256 public flowCost;

    address private NFT;

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

    constructor(uint256 _flowCost) Ownable(msg.sender) {
        flowCost = _flowCost;
        payee = payable(msg.sender);
    }

    function setNFTAddress(address to) external onlyOwner {
        NFT = to;
    }

    function setFlowcost(uint256 to) external onlyOwner {
        flowCost = to;
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
        string calldata name,
        string calldata coupon,
        address erc20Address,
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint16 min,
        uint16 max,
        uint16 betType
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
            //Calculate the percentage off
            uint256 newPrice = getReducedPrice(coupon);
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
            require(msg.value == flowCost, "Invalid price");
            Address.sendValue(payee, msg.value);
        }

        uint16[3] memory betParams = [min,max,betType];

        IFlowRollNFT(NFT).mintFlowRoll(
            msg.sender,
            erc20Address,
            winnerPrizeShare,
            diceRollCost,
            houseEdge,
            0, //No reveal compensation because of scheduled transactions
            betParams,
            name
        );
    }


    function getReducedPrice(
        string calldata coupon
    ) public view returns (uint256) {
        uint256 subFromPrice = (flowCost / 100) * couponPercentageOff[coupon];
        return flowCost - subFromPrice;
    }

    function getcommission(
        uint256 newPrice,
        string calldata coupon
    ) public view returns (uint256) {
        return (newPrice / 100) * couponcommission[coupon];
    }
}
