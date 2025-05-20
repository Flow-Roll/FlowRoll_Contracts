//ONLY USED FOR TESTING, mocking Randomness provider
contract MockRandProvider {
    uint64 private index;

    mapping(uint256 => uint64) requests;

    function getRandomnessRequestId() external returns (uint256) {
        return index;
    }

    function fulfillRandomnessRequest(
        uint256 requestId,
        uint64 min,
        uint64 max
    ) external returns (uint64) {
        return requests[requestId];
    }

    function setRequestRandomness(uint256 index, uint64 to) external {
        requests[index] = to;
    }

    function setIndex(uint64 _index) external {
        index = _index;
    }
}
