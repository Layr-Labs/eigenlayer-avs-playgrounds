// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPlaygroundAVSServiceManagerV1 {
    // EVENTS

    event DummyEvent(DummyStruct);

    // STRUCTS

    struct DummyStruct {
        uint256 dummyTaskNum;
    }

    // FUNCTIONS

    function createDummyTask() external;
}
