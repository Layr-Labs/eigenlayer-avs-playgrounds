// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/core/PlaygroundServiceManagerV1.sol";

contract CounterTest is Test {
    PlaygroundServiceManagerV1 public playgroundAVS;

    function setUp() public {
        // TODO
        // playgroundAVS = new PlaygroundServiceManagerV1();
    }

    function testDummyFunction() public {
        playgroundAVS.dummyFunction();
    }
}
