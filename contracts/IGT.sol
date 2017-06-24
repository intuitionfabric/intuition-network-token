pragma solidity ^0.4.11;

/*
    Copyright 2017, Jarrad Hope (Status Research & Development GmbH)
    Copyright 2017, Carlos Perez (Intuition Machine Inc)
*/


import "./MiniMeToken.sol";


contract IGT is MiniMeToken {

    uint256 constant D160 = 0x0010000000000000000000000000000000000000000;

    function IGT(address _tokenFactory)
            MiniMeToken(
                _tokenFactory,
                0x0,                     // no parent token
                0,                       // no snapshot block number from parent
                "Intuition Genesis Token",  // Token name
                1,                       // Decimals
                "IGT",                   // Symbol
                false                    // Enable transfers
            ) {}

    // data is an array of uint256s. Each uint256 represents a transfer.
    // The 160 LSB is the destination of the address that wants to be sent
    // The 96 MSB is the amount of tokens that wants to be sent.
    function multiMint(uint256[] data) public onlyController {
        for (uint256 i = 0; i < data.length; i++) {
            address addr = address(data[i] & (D160 - 1));
            uint256 amount = data[i] / D160;

            assert(generateTokens(addr, amount));
        }
    }

}
