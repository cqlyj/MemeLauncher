// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";
import {MemeToken} from "src/MemeToken.sol";

contract MemeTokenTest is Test {
    MemeToken memeToken;
    string name = "MemeToken";
    string symbol = "MEME";
    address creator = makeAddr("creator");
    uint256 constant TOTAL_SUPPLY = 1_000_000 ether; // 1 million MEME

    function setUp() public {
        memeToken = new MemeToken(name, symbol, creator, TOTAL_SUPPLY);
    }

    function testMemeTokenHaveNameAndSymbol() public view {
        assertEq(memeToken.name(), name);
        assertEq(memeToken.symbol(), symbol);
    }
}
