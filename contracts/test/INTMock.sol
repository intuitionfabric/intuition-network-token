pragma solidity ^0.4.11;

import '../INT.sol';

// @dev INTMock mocks current block number

contract INTMock is INT {

    function INTMock(address _tokenFactory) INT(_tokenFactory) {}

    function getBlockNumber() internal constant returns (uint) {
        return mock_blockNumber;
    }

    function setMockedBlockNumber(uint _b) public {
        mock_blockNumber = _b;
    }

    uint mock_blockNumber = 1;
}
