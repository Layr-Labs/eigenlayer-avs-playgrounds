// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/core/PlaygroundAVSServiceManagerV1.sol";

contract CounterTest is Test {
    PlaygroundAVSServiceManagerV1 public playgroundAVS;

    function setUp() public {
        // TODO
        // playgroundAVS = new PlaygroundAVSServiceManagerV1();
    }

    function testDummyFunction() public {
        playgroundAVS.dummyFunction();
    }
}
