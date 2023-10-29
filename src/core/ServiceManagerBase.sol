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
import "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import "@eigenlayer/contracts/interfaces/IDelayedService.sol";

import "@eigenlayer/contracts/libraries/BytesLib.sol";
import "@eigenlayer/contracts/libraries/Merkle.sol";
import "@eigenlayer/contracts/permissions/Pausable.sol";

/**
 * @title Primary entrypoint for procuring services from PlaygroundAVSServiceManagerV1.
 * @author Layr Labs, Inc.
 * @notice This contract is used for:
 * - initializing the data store by the disperser
 * - confirming the data store by the disperser with inferred aggregated signatures of the quorum
 * - freezing operators as the result of various "challenges"
 */
abstract contract ServiceManagerBase is
    IServiceManager,
    IDelayedService,
    Initializable,
    OwnableUpgradeable,
    BLSSignatureChecker,
    Pausable
{
    using BytesLib for bytes;

    // =============== VIRTUAL SECTION ===============

    /**
     * @notice The maximum amount of blocks in the past that the service will consider stake amounts to still be 'valid'.
     * @dev To clarify edge cases, the middleware can look `BLOCK_STALE_MEASURE` blocks into the past, i.e. it may trust stakes from the interval
     * [block.number - BLOCK_STALE_MEASURE, block.number] (specifically, *inclusive* of the block that is `BLOCK_STALE_MEASURE` before the current one)
     * @dev BLOCK_STALE_MEASURE should be greater than the number of blocks till finalization, but not too much greater, as it is the amount of
     * time that nodes can be active after they have deregistered. The larger it is, the farther back stakes can be used, but the longer operators
     * have to serve after they've deregistered.
     */
    uint32 public immutable BLOCK_STALE_MEASURE;

    /// @notice Unit of measure (in blocks) for which task will last.
    uint32 public immutable TASK_DURATION_BLOCKS;

    /// @notice Called in the event of challenge resolution, in order to forward a call to the Slasher, which 'freezes' the `operator`.
    function freezeOperator(address operatorAddr) external virtual;

    // =============== END VIRTUAL SECTION ===============

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

    /// @notice when applied to a function, ensures that the function is only callable by the `registryCoordinator`.
    /// or by StakeRegistry
    modifier onlyRegistryCoordinatorOrStakeRegistry() {
        require(
            (msg.sender == address(registryCoordinator)) ||
                (msg.sender ==
                    address(
                        IBLSRegistryCoordinatorWithIndices(
                            address(registryCoordinator)
                        ).stakeRegistry()
                    )),
            "onlyRegistryCoordinatorOrStakeRegistry: not from registry coordinator or stake registry"
        );
        _;
    }

    constructor(
        IBLSRegistryCoordinatorWithIndices _registryCoordinator,
        IStrategyManager _strategyManager,
        IDelegationManager _delegationMananger,
        ISlasher _slasher,
        uint32 _TASK_DURATION_BLOCKS,
        uint32 _BLOCK_STALE_MEASURE
    ) BLSSignatureChecker(_registryCoordinator) {
        strategyManager = _strategyManager;
        delegationManager = _delegationMananger;
        slasher = _slasher;
        TASK_DURATION_BLOCKS = _TASK_DURATION_BLOCKS;
        BLOCK_STALE_MEASURE = _BLOCK_STALE_MEASURE;
        _disableInitializers();
    }

    function initialize(
        IPauserRegistry _pauserRegistry,
        address initialOwner
    ) public initializer {
        _initializePauser(_pauserRegistry, UNPAUSE_ALL);
        _transferOwnership(initialOwner);
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
    ) external onlyRegistryCoordinatorOrStakeRegistry {
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
}
