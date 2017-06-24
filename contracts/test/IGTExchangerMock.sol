pragma solidity ^0.4.11;

import '../IGTExchanger.sol';

// @dev IGTExchangerMock mocks current block number

contract IGTExchangerMock is IGTExchanger {

    function IGTExchangerMock(address _igt, address _snt, address _statusContribution)
        IGTExchanger(_igt,  _snt, _statusContribution) {}

    function getBlockNumber() internal constant returns (uint) {
        return mock_blockNumber;
    }

    function setMockedBlockNumber(uint _b) public {
        mock_blockNumber = _b;
    }

    uint public mock_blockNumber = 1;
}
