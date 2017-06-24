pragma solidity ^0.4.11;

import '../INTPlaceHolder.sol';

// @dev INTPlaceHolderMock mocks current block number

contract INTPlaceHolderMock is INTPlaceHolder {

    uint mock_time;

    function INTPlaceHolderMock(address _owner, address _int, address _contribution, address _sgtExchanger)
            INTPlaceHolder(_owner, _int, _contribution, _sgtExchanger) {
        mock_time = now;
    }

    function getTime() internal returns (uint) {
        return mock_time;
    }

    function setMockedTime(uint _t) public {
        mock_time = _t;
    }
}
