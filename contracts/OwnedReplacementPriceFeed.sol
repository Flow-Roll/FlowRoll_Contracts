//This is used instead of the regular price feeds from PYTH because that adds an extra cost

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/access/Ownable.sol";

contract OwnedReplacementFlowUSDPriceFeed is Ownable {
    uint256 public alpha = 1e18; // Smoothing factor, scaled by 1e18 (e.g., 0.1 * 1e18 = 100000000000000000)

    int64 price;

    int32 exponent = -8;

    constructor() Ownable(msg.sender){}

    //Owner can set price
    function setPrice(int64 to, int32 expo) external onlyOwner {
        price = to;
        exponent = expo;
    }

    //This replaces the oracle feed
    function getPrice() external view returns (int64, int32) {
        return (price, exponent);
    }

    /**
     * @notice Returns the EWMA price using new oracle data
     * @param mantissa The raw integer price from the oracle (e.g., 4049444)
     * @param exponent The number of decimals the mantissa should be divided by (e.g., 8)
     */
    function getEWMAPrice(
        uint256 mantissa,
        uint256 exponent
    ) external returns (uint256) {
        require(exponent <= 77, "Exponent too large"); // Prevent overflow: 10^77 is close to uint256 max
        uint256 denominator = 10 ** exponent;

        // Convert price to fixed-point (1e18 scale)
        uint256 price = (mantissa * 1e18) / denominator;
        return price;
    }
}
