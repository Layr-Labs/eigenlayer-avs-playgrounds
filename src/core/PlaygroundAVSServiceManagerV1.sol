// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import "@eigenlayer/contracts/middleware/BLSSignatureChecker.sol";

import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/interfaces/IDelegationTerms.sol";
import "@eigenlayer/contracts/interfaces/IPaymentManager.sol";
import "@eigenlayer/contracts/interfaces/IServiceManager.sol";

import "@eigenlayer/contracts/libraries/BytesLib.sol";
import "@eigenlayer/contracts/libraries/Merkle.sol";
import "@eigenlayer/contracts/permissions/Pausable.sol";

import "./PlaygroundAVSServiceManagerV1Storage.sol";

/**
 * @title Primary entrypoint for procuring services from PlaygroundAVSServiceManagerV1.
 * @author Layr Labs, Inc.
 * @notice This contract is used for:
 * - initializing the data store by the disperser
 * - confirming the data store by the disperser with inferred aggregated signatures of the quorum
 * - freezing operators as the result of various "challenges"
 */
contract PlaygroundAVSServiceManagerV1 is
    IServiceManager,
    Initializable,
    OwnableUpgradeable,
    PlaygroundAVSServiceManagerV1Storage,
    BLSSignatureChecker,
    Pausable
{
    using BytesLib for bytes;

    uint8 internal constant _PAUSED_CONFIRM_BATCH = 0;

    /**
     * @notice EigenLayer contracts
     */
    IDelegationManager public immutable delegationManager;
    IStrategyManager public immutable strategyManager;
    ISlasher public immutable slasher;

    /// @notice when applied to a function, ensures that the function is only callable by the `registryCoordinator`.
    modifier onlyRegistryCoordinator() {
        require(
            msg.sender == address(registryCoordinator),
            "onlyRegistryCoordinator: not from registry coordinator"
        );
        _;
    }

    constructor(
        IBLSRegistryCoordinatorWithIndices _registryCoordinator,
        IStrategyManager _strategyManager,
        IDelegationManager _delegationMananger,
        ISlasher _slasher
    ) BLSSignatureChecker(_registryCoordinator) {
        strategyManager = _strategyManager;
        delegationManager = _delegationMananger;
        slasher = _slasher;
        _disableInitializers();
    }

    function initialize(
        IPauserRegistry _pauserRegistry,
        address initialOwner
    ) public initializer {
        _initializePauser(_pauserRegistry, UNPAUSE_ALL);
        _transferOwnership(initialOwner);
    }

    /// @notice Called in the event of challenge resolution, in order to forward a call to the Slasher, which 'freezes' the `operator`.
    function freezeOperator(address /*operator*/) external {
        revert("PlaygroundAVSServiceManagerV1.freezeOperator: not implemented");
        // require(
        //     msg.sender == address(???),
        //     "PlaygroundAVSServiceManagerV1.freezeOperator: Only ??? can slash operators"
        // );
        // slasher.freezeOperator(operator);
    }

    /**
     * @notice Called by the Registry in the event of a new registration, to forward a call to the Slasher
     * @param operator The operator whose stake is being updated
     * @param serveUntilBlock The block until which the stake accounted for in the first update is slashable by this middleware
     */
    function recordFirstStakeUpdate(
        address operator,
        uint32 serveUntilBlock
    ) external onlyRegistryCoordinator {
        slasher.recordFirstStakeUpdate(operator, serveUntilBlock);
    }

    /**
     * @notice Called by the registryCoordinator, in order to forward a call to the Slasher, informing it of a stake update
     * @param operator The operator whose stake is being updated
     * @param updateBlock The block at which the update is being made
     * @param serveUntilBlock The block until which the stake withdrawn from the operator in this update is slashable by this middleware
     * @param prevElement The value of the previous element in the linked list of stake updates (generated offchain)
     */
    function recordStakeUpdate(
        address operator,
        uint32 updateBlock,
        uint32 serveUntilBlock,
        uint256 prevElement
    ) external onlyRegistryCoordinator {
        slasher.recordStakeUpdate(
            operator,
            updateBlock,
            serveUntilBlock,
            prevElement
        );
    }

    /**
     * @notice Called by the registryCoordinator in the event of deregistration, to forward a call to the Slasher
     * @param operator The operator being deregistered
     * @param serveUntilBlock The block until which the stake delegated to the operator is slashable by this middleware
     */
    function recordLastStakeUpdateAndRevokeSlashingAbility(
        address operator,
        uint32 serveUntilBlock
    ) external onlyRegistryCoordinator {
        slasher.recordLastStakeUpdateAndRevokeSlashingAbility(
            operator,
            serveUntilBlock
        );
    }

    // VIEW FUNCTIONS
    function taskNumber() external view returns (uint32) {
        return taskNum;
    }

    /// @notice Returns the block until which operators must serve.
    function latestServeUntilBlock() external view returns (uint32) {
        return
            uint32(block.number) + TASK_DURATION_BLOCKS + BLOCK_STALE_MEASURE;
    }

    /// @dev need to override function here since its defined in both these contracts
    function owner()
        public
        view
        override(OwnableUpgradeable, IServiceManager)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    function dummyFunction() external {
        DummyStruct memory dummyStruct = DummyStruct({dummyUint: 0});
        emit DummyEvent(dummyStruct);
    }
}
