// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {CadenceRandomConsumer} from "@onflow/flow-sol-utils/src/random/CadenceRandomConsumer.sol";

contract RandProvider is CadenceRandomConsumer {
    function getRandomnessRequestId() external returns (uint256) {
        return _requestRandomness();
    }

    function fulfillRandomnessRequest(
        uint256 requestId,
        uint64 min,
        uint64 max
    ) external returns (uint64) {
        return _fulfillRandomInRange(requestId, min, max);
    }
}
