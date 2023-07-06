// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/interfaces/IServiceManager.sol";
import "@eigenlayer/contracts/interfaces/IStrategyManager.sol";

import "../interfaces/IPlaygroundServiceManagerV1.sol";

/**
 * @title Storage variables for the `PlaygroundServiceManagerV1` contract.
 * @author Layr Labs, Inc.
 * @notice This storage contract is separate from the logic to simplify the upgrade process.
 */
abstract contract PlaygroundServiceManagerV1Storage is IPlaygroundServiceManagerV1 {
    // CONSTANTS

    /// @notice Unit of measure (in blocks) for which data will be stored for after confirmation.
    uint32 public constant TASK_DURATION_BLOCKS = 2 weeks / 12 seconds;

    /**
     * @notice The maximum amount of blocks in the past that the service will caonsider stake amounts to still be 'valid'.
     * @dev To clarify edge cases, the middleware can look `BLOCK_STALE_MEASURE` blocks into the past, i.e. it may trust stakes from the interval
     * [block.number - BLOCK_STALE_MEASURE, block.number] (specifically, *inclusive* of the block that is `BLOCK_STALE_MEASURE` before the current one)
     * @dev BLOCK_STALE_MEASURE should be greater than the number of blocks till finalization, but not too much greater, as it is the amount of
     * time that nodes can be active after they have deregistered. The larger it is, the farther back stakes can be used, but the longer operators
     * have to serve after they've deregistered.
     */
    uint32 public constant BLOCK_STALE_MEASURE = 150;

    /// @notice The current task number
    uint32 public taskNum;

    /// @notice mapping between the taskNumber to the hash of the metadata of the corresponding task
    mapping(uint32 => bytes32) public taskNumToTaskMetadataHash;
}