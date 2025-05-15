import {CadenceRandomConsumer} from "@onflow/flow-sol-utils/src/random/CadenceRandomConsumer.sol";

contract RandProvider is CadenceRandomConsumer {
    function getRandomnessRequestId() external returns (uint256) {
        return _requestRandomness();
    }

    function fulfilRandomnessRequest(
        uint256 requestId,
        uint64 min,
        uint64 max
    ) external returns (uint64) {
        return _fulfillRandomInRange(requestId, min, max);
    }
}
