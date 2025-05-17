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
        uint8 min,
        uint8 max
    ) external;
}

contract NFTSale is Ownable {
    using Address for address payable;
    address payable private payee;

    uint256 private price;

    address private NFT;

    mapping(string => address) couponAddresses;

    mapping(string => uint8) couponPercentageOff;

    mapping(string => uint8) couponComission;

    constructor(uint256 _price) Ownable(msg.sender) {
        price = _price;
        payee = payable(msg.sender);
    }

    function setNFTAddress(address to) external onlyOwner {
        NFT = to;
    }

    function setPrice(uint256 to) external onlyOwner {
        price = to;
    }

    function setCoupon(
        string calldata coupon,
        address recipient,
        uint8 percentageOff,
        uint8 comission
    ) external onlyOwner {
        require(recipient != address(0), "invalid recipient");
        couponAddresses[coupon] = recipient;
        require(percentageOff < 20, "Max 2 percent off");
        couponPercentageOff[coupon] = percentageOff;
        require(comission < 20, "Max 20 percent comission");
        couponComission[coupon] = comission;
    }

    function getCoupon(
        string calldata coupon
    ) external returns (address, uint8, uint8) {
        return (
            couponAddresses[coupon],
            couponPercentageOff[coupon],
            couponComission[coupon]
        );
    }

    function buyNFT(
        string calldata coupon,
        address to,
        address ERC20Address, //THe ERC20Address parameter if 0 means the game is played for flow, else the specific ERC20 token
        uint8 winnerPrizeShare,
        uint256 diceRollCost,
        uint8 houseEdge,
        uint256 revealCompensation,
        uint8 min,
        uint8 max
    ) external payable {
        if (bytes(coupon).length != 0) {
            //Check if the coupon is valid and if not then revert
            require(couponAddresses[coupon] != address(0), "Inalid coupon");
            //Calculate the percentage off
            uint256 newPrice = getNewPrice(coupon);
            require(newPrice == msg.value, "Inavlid price with coupon");
            uint256 comission = getComission(newPrice, coupon);
            //The sale profit is newPrice minus the comission
            uint256 profit = newPrice - comission;
            Address.sendValue(payee, profit);
            //Forward the payments
            Address.sendValue(payable(couponAddresses[coupon]), comission);
        } else {
            require(msg.value == price, "Invalid price");
            Address.sendValue(payee, msg.value);
        }

        IFlowRollNFT(NFT).mintFlowRoll(
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

    function getNewPrice(string calldata coupon) public view returns (uint256) {
        uint256 subFromPrice = (price / 100) * couponPercentageOff[coupon];
        return price - subFromPrice;
    }

    function getComission(
        uint256 newPrice,
        string calldata coupon
    ) public view returns (uint256) {
        return (newPrice / 100) * couponComission[coupon];
    }
}
