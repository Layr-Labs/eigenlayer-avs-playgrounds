// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/interfaces/IDelegationTerms.sol";
import "@eigenlayer/contracts/interfaces/IPaymentManager.sol";
import "@eigenlayer/contracts/interfaces/IServiceManager.sol";

import "@eigenlayer/contracts/libraries/BytesLib.sol";
import "@eigenlayer/contracts/libraries/Merkle.sol";
import "@eigenlayer/contracts/permissions/Pausable.sol";

import "../interfaces/IPlaygroundAVSServiceManagerV1.sol";
import "./ServiceManagerBase.sol";

// TODO: write this as base contract, and have PlaygroundAVSServiceManagerV1 inherit from it
// so that avs teams don't need to read all the other proxy calls
/**
 * @title Primary entrypoint for procuring services from PlaygroundAVSServiceManagerV1.
 * @author Layr Labs, Inc.
 * @notice This contract is used for:
 * - initializing the data store by the disperser
 * - confirming the data store by the disperser with inferred aggregated signatures of the quorum
 * - freezing operators as the result of various "challenges"
 */
contract PlaygroundAVSServiceManagerV1 is
    ServiceManagerBase,
    IPlaygroundAVSServiceManagerV1
{
    using BytesLib for bytes;

    /// @notice The current task number
    uint32 public taskNum;

    constructor(
        IBLSRegistryCoordinatorWithIndices _registryCoordinator,
        IStrategyManager _strategyManager,
        IDelegationManager _delegationMananger,
        ISlasher _slasher,
        uint32 _blockStaleMeasure,
        uint32 _taskDurationBlocks
    )
        ServiceManagerBase(
            _registryCoordinator,
            _strategyManager,
            _delegationMananger,
            _slasher,
            _blockStaleMeasure,
            _taskDurationBlocks
        )
    {}

    /// @notice Called in the event of challenge resolution, in order to forward a call to the Slasher, which 'freezes' the `operator`.
    function freezeOperator(address operatorAddr) external override {
        // require(
        //     msg.sender == address(???),
        //     "PlaygroundAVSServiceManagerV1.freezeOperator: Only ??? can slash operators"
        // );
        slasher.freezeOperator(operatorAddr);
    }

    // VIEW FUNCTIONS
    function taskNumber() external view returns (uint32) {
        return taskNum;
    }

    function createDummyTask() external {
        DummyStruct memory dummyStruct = DummyStruct({dummyTaskNum: taskNum});
        emit DummyEvent(dummyStruct);
        taskNum++;
    }
}
