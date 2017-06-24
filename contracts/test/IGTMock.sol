pragma solidity ^0.4.11;

import '../IGT.sol';

// @dev IGTMock mocks current block number

contract IGTMock is IGT {

    function IGTMock(address _tokenFactory) IGT(_tokenFactory) {}

    function getBlockNumber() internal constant returns (uint) {
        return mock_blockNumber;
    }

    function setMockedBlockNumber(uint _b) public {
        mock_blockNumber = _b;
    }

    uint mock_blockNumber = 1;
}
