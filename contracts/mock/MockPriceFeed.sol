// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockFlowUSDPriceFeed {
    int64 price;

    function setPrice(int64 to) external {
        price = to;
    }

    function getPrice() external returns (int64) {
        return price;
    }
}
