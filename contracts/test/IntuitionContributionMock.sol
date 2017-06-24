pragma solidity ^0.4.11;

import '../IntuitionContribution.sol';

// @dev IntuitionContributionMock mocks current block number

contract IntuitionContributionMock is IntuitionContribution {

    function IntuitionContributionMock() IntuitionContribution() {}

    function getBlockNumber() internal constant returns (uint) {
        return mock_blockNumber;
    }

    function setMockedBlockNumber(uint _b) public {
        mock_blockNumber = _b;
    }

    uint mock_blockNumber = 1;
}
