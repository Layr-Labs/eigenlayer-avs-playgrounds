// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

import "@eigenlayer/contracts/permissions/PauserRegistry.sol";

import "@eigenlayer/contracts/middleware/BLSPublicKeyCompendium.sol";
import "@eigenlayer/contracts/middleware/BLSRegistryCoordinatorWithIndices.sol";
import "@eigenlayer/contracts/middleware/BLSPubkeyRegistry.sol";
import "@eigenlayer/contracts/middleware/IndexRegistry.sol";
import "@eigenlayer/contracts/middleware/StakeRegistry.sol";
import "@eigenlayer/contracts/middleware/BLSOperatorStateRetriever.sol";

import "@eigenlayer/test/mocks/EmptyContract.sol";

import "../src/core/PlaygroundAVSServiceManagerV1.sol";

import "./utils/Utils.sol";

import "forge-std/Test.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

// TODO: REVIEW AND FIX THIS ENTIRE SCRIPT

// # To load the variables in the .env file
// source .env

// # To deploy and verify our contract
// forge script script/PlaygroundAVSDeployer.s.sol:PlaygroundAVSDeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract PlaygroundAVSDeployer is Script, Utils {
    // PlaygroundAVS contracts
    ProxyAdmin public playgroundAVSProxyAdmin;
    PauserRegistry public playgroundAVSPauserReg;

    BLSPublicKeyCompendium public pubkeyCompendium;
    PlaygroundAVSServiceManagerV1 public playgroundAVSServiceManagerV1;
    BLSRegistryCoordinatorWithIndices public registryCoordinator;
    IBLSPubkeyRegistry public blsPubkeyRegistry;
    IIndexRegistry public indexRegistry;
    IStakeRegistry public stakeRegistry;
    BLSOperatorStateRetriever public blsOperatorStateRetriever;

    PlaygroundAVSServiceManagerV1
        public PlaygroundAVSServiceManagerV1Implementation;
    IBLSRegistryCoordinatorWithIndices public registryCoordinatorImplementation;
    IBLSPubkeyRegistry public blsPubkeyRegistryImplementation;
    IIndexRegistry public indexRegistryImplementation;
    IStakeRegistry public stakeRegistryImplementation;

    function run() external {
        string memory configData = readOutput("eigenlayer_deployment_output");
        IStrategyManager strategyManager = IStrategyManager(
            stdJson.readAddress(configData, ".addresses.strategyManager")
        );
        IDelegationManager delegationManager = IDelegationManager(
            stdJson.readAddress(configData, ".addresses.delegation")
        );
        ISlasher slasher = ISlasher(
            stdJson.readAddress(configData, ".addresses.slasher")
        );
        IStrategy strat = IStrategy(
            stdJson.readAddress(configData, ".addresses.baseStrategy")
        );

        address playgroundAVSCommunityMultisig = msg.sender;
        address playgroundAVSPauser = msg.sender;

        vm.startBroadcast();
        _deployPlaygroundAVSContracts(
            strategyManager,
            delegationManager,
            slasher,
            strat,
            playgroundAVSCommunityMultisig,
            playgroundAVSPauser
        );
        vm.stopBroadcast();
    }

    function _deployPlaygroundAVSContracts(
        IStrategyManager strategyManager,
        IDelegationManager delegationManager,
        ISlasher slasher,
        IStrategy strat,
        address playgroundAVSCommunityMultisig,
        address playgroundAVSPauser
    ) internal {
        // Adding this as a temporary fix to make the rest of the script work with a single strategy
        // since it was originally written to work with an array of strategies
        IStrategy[1] memory deployedStrategyArray = [strat];
        uint numStrategies = deployedStrategyArray.length;

        // deploy proxy admin for ability to upgrade proxy contracts
        playgroundAVSProxyAdmin = new ProxyAdmin();

        // deploy pauser registry
        {
            address[] memory pausers = new address[](2);
            pausers[0] = playgroundAVSPauser;
            pausers[1] = playgroundAVSCommunityMultisig;
            playgroundAVSPauserReg = new PauserRegistry(
                pausers,
                playgroundAVSCommunityMultisig
            );
        }

        EmptyContract emptyContract = new EmptyContract();

        // hard-coded inputs

        /**
         * First, deploy upgradeable proxy contracts that **will point** to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the initial implementation, to act as if they have no code.
         */
        playgroundAVSServiceManagerV1 = PlaygroundAVSServiceManagerV1(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(playgroundAVSProxyAdmin),
                    ""
                )
            )
        );
        pubkeyCompendium = new BLSPublicKeyCompendium();
        registryCoordinator = BLSRegistryCoordinatorWithIndices(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(playgroundAVSProxyAdmin),
                    ""
                )
            )
        );
        blsPubkeyRegistry = IBLSPubkeyRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(playgroundAVSProxyAdmin),
                    ""
                )
            )
        );
        indexRegistry = IIndexRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(playgroundAVSProxyAdmin),
                    ""
                )
            )
        );
        stakeRegistry = IStakeRegistry(
            address(
                new TransparentUpgradeableProxy(
                    address(emptyContract),
                    address(playgroundAVSProxyAdmin),
                    ""
                )
            )
        );

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        {
            stakeRegistryImplementation = new StakeRegistry(
                registryCoordinator,
                strategyManager,
                playgroundAVSServiceManagerV1
            );

            // set up a quorum with each strategy that needs to be set up
            uint96[] memory minimumStakeForQuorum = new uint96[](numStrategies);
            IVoteWeigher.StrategyAndWeightingMultiplier[][]
                memory strategyAndWeightingMultipliers = new IVoteWeigher.StrategyAndWeightingMultiplier[][](
                    numStrategies
                );
            for (uint i = 0; i < numStrategies; i++) {
                strategyAndWeightingMultipliers[
                    i
                ] = new IVoteWeigher.StrategyAndWeightingMultiplier[](1);
                strategyAndWeightingMultipliers[i][0] = IVoteWeigher
                    .StrategyAndWeightingMultiplier({
                        strategy: deployedStrategyArray[i],
                        multiplier: 1 gwei
                    });
            }

            playgroundAVSProxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(stakeRegistry))),
                address(stakeRegistryImplementation),
                abi.encodeWithSelector(
                    StakeRegistry.initialize.selector,
                    minimumStakeForQuorum,
                    strategyAndWeightingMultipliers
                )
            );
        }

        registryCoordinatorImplementation = new BLSRegistryCoordinatorWithIndices(
            slasher,
            playgroundAVSServiceManagerV1,
            stakeRegistry,
            blsPubkeyRegistry,
            indexRegistry
        );

        {
            IBLSRegistryCoordinatorWithIndices.OperatorSetParam[]
                memory operatorSetParams = new IBLSRegistryCoordinatorWithIndices.OperatorSetParam[](
                    numStrategies
                );
            for (uint i = 0; i < numStrategies; i++) {
                // hard code these for now
                operatorSetParams[i] = IBLSRegistryCoordinatorWithIndices
                    .OperatorSetParam({
                        maxOperatorCount: 10000,
                        kickBIPsOfOperatorStake: 15000,
                        kickBIPsOfAverageStake: 5000,
                        kickBIPsOfTotalStake: 100
                    });
            }
            playgroundAVSProxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(
                    payable(address(registryCoordinator))
                ),
                address(registryCoordinatorImplementation),
                abi.encodeWithSelector(
                    BLSRegistryCoordinatorWithIndices.initialize.selector,
                    operatorSetParams
                )
            );
        }

        blsPubkeyRegistryImplementation = new BLSPubkeyRegistry(
            registryCoordinator,
            pubkeyCompendium
        );

        playgroundAVSProxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blsPubkeyRegistry))),
            address(blsPubkeyRegistryImplementation)
        );

        indexRegistryImplementation = new IndexRegistry(registryCoordinator);

        playgroundAVSProxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(indexRegistry))),
            address(indexRegistryImplementation)
        );

        PlaygroundAVSServiceManagerV1Implementation = new PlaygroundAVSServiceManagerV1(
            registryCoordinator,
            strategyManager,
            delegationManager,
            slasher
        );

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        playgroundAVSProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(
                payable(address(playgroundAVSServiceManagerV1))
            ),
            address(PlaygroundAVSServiceManagerV1Implementation),
            abi.encodeWithSelector(
                PlaygroundAVSServiceManagerV1.initialize.selector,
                playgroundAVSPauserReg,
                playgroundAVSCommunityMultisig,
                0,
                playgroundAVSCommunityMultisig
            )
        );

        blsOperatorStateRetriever = new BLSOperatorStateRetriever(
            registryCoordinator
        );

        // WRITE JSON DATA
        string memory parent_object = "parent object";

        string memory deployed_addresses = "addresses";
        vm.serializeAddress(
            deployed_addresses,
            "blsOperatorStateRetriever",
            address(blsOperatorStateRetriever)
        );
        vm.serializeAddress(
            deployed_addresses,
            "playgroundAVSServiceManager",
            address(playgroundAVSServiceManagerV1)
        );
        vm.serializeAddress(
            deployed_addresses,
            "playgroundAVSServiceManagerV1Implementation",
            address(PlaygroundAVSServiceManagerV1Implementation)
        );
        vm.serializeAddress(
            deployed_addresses,
            "registryCoordinator",
            address(registryCoordinator)
        );
        string memory deployed_addresses_output = vm.serializeAddress(
            deployed_addresses,
            "registryCoordinatorImplementation",
            address(registryCoordinatorImplementation)
        );

        // serialize all the data
        string memory finalJson = vm.serializeString(
            parent_object,
            deployed_addresses,
            deployed_addresses_output
        );

        writeOutput(finalJson, "playground_avs_deployment_output");
    }
}
