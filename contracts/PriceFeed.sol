// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

//This contract uses Pyth
contract FlowUsdPriceFeed {
    IPyth pyth;
    bytes32 flowusd_identifier;

    uint256 private alpha = 1e18; //Smoothing factor

    /**
     * @param pythContract The address of the Pyth contract
     _flow_usd_identifier is Crypto.FLOW/USD 0x2fb245b9a84554a0f15aa123cbb5f64cd263b59e9a87d80148cbffab50c69f30 stable
     */
    constructor(address pythContract, bytes32 _flowusd_identifier) {
        // The IPyth interface from pyth-sdk-solidity provides the methods to interact with the Pyth contract.
        // Instantiate it with the Pyth contract address from https://docs.pyth.network/price-feeds/contract-addresses/evm
        pyth = IPyth(pythContract);
        flowusd_identifier = _flowusd_identifier;
    }

    //Returns the mantissa and the expo which is negative
    function getPrice() external returns (int64, int32) {
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            flowusd_identifier,
            60
        );
        return (price.price, price.expo);
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
