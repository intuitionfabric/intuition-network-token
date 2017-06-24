pragma solidity ^0.4.11;

/*
    Copyright 2017, Jarrad Hope (Status Research & Development GmbH)
    Copyright 2017, Carlos Perez (Intuition Machine Inc)
*/


import "./MiniMeToken.sol";


contract INT is MiniMeToken {
    // @dev INT constructor just parametrizes the MiniMeIrrevocableVestedToken constructor
    function INT(address _tokenFactory)
            MiniMeToken(
                _tokenFactory,
                0x0,                     // no parent token
                0,                       // no snapshot block number from parent
                "Intuition Network Token",  // Token name
                18,                      // Decimals
                "INT",                   // Symbol
                true                     // Enable transfers
            ) {}
}
