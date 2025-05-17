// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

//This contract uses Pyth
contract FlowUsdPriceFeed {
    IPyth pyth;
    bytes32 flowusd_identifier;

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

    function getPrice() external returns (int64) {
        PythStructs.Price memory price = pyth.getPriceNoOlderThan(
            flowusd_identifier,
            60
        );
        return price.price;
    }
}
