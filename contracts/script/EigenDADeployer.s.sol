// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@eigenlayer-scripts/middleware/DeployOpenEigenLayer.s.sol";

import "@eigenlayer/contracts/permissions/PauserRegistry.sol";

import "@eigenlayer/contracts/middleware/BLSPublicKeyCompendium.sol";
import "@eigenlayer/contracts/middleware/BLSRegistryCoordinatorWithIndices.sol";
import "@eigenlayer/contracts/middleware/BLSPubkeyRegistry.sol";
import "@eigenlayer/contracts/middleware/IndexRegistry.sol";
import "@eigenlayer/contracts/middleware/StakeRegistry.sol";
import "@eigenlayer/contracts/middleware/BLSOperatorStateRetriever.sol";

import "@eigenlayer/test/mocks/EmptyContract.sol";

import "../src/core/PlaygroundServiceManagerV1.sol";

import "forge-std/Test.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

// TODO: REVIEW AND FIX THIS ENTIRE SCRIPT

// # To load the variables in the .env file
// source .env

// # To deploy and verify our contract
// forge script script/Deployer.s.sol:EigenDADeployer --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract EigenDADeployer is DeployOpenEigenLayer {
    // EigenDA contracts
    ProxyAdmin public eigenDAProxyAdmin;
    PauserRegistry public eigenDAPauserReg;

    BLSPublicKeyCompendium public pubkeyCompendium;
    EigenDAServiceManager public eigenDAServiceManager;
    BLSRegistryCoordinatorWithIndices public registryCoordinator;
    IBLSPubkeyRegistry public blsPubkeyRegistry;
    IIndexRegistry public indexRegistry;
    IStakeRegistry public stakeRegistry;
    BLSOperatorStateRetriever public blsOperatorStateRetriever;

    EigenDAServiceManager public eigenDAServiceManagerImplementation;
    IBLSRegistryCoordinatorWithIndices public registryCoordinatorImplementation;
    IBLSPubkeyRegistry public blsPubkeyRegistryImplementation;
    IIndexRegistry public indexRegistryImplementation;
    IStakeRegistry public stakeRegistryImplementation;
    
    function _deployEigenDAAndEigenLayerContracts(
        address eigenLayerCommunityMultisig,
        address eigenLayerOperationsMultisig,
        address eigenLayerPauserMultisig,
        address eigenDACommunityMultisig,
        address eigenDAPauser,
        uint8 numStrategies,
        uint256 initialSupply,
        address tokenOwner
    ) internal {
        StrategyConfig[] memory strategyConfigs = new StrategyConfig[](numStrategies);
        // deploy a token and create a strategy config for each token
        for (uint8 i = 0; i < numStrategies; i++) {
            address tokenAddress = address(new ERC20PresetFixedSupply(string(abi.encodePacked("Token", i)), string(abi.encodePacked("TOK", i)), initialSupply, tokenOwner));
            strategyConfigs[i] = StrategyConfig({
                maxDeposits: type(uint256).max,
                maxPerDeposit: type(uint256).max,
                tokenAddress: tokenAddress,
                tokenSymbol: string(abi.encodePacked("TOK", i))
            });
        }

        _deployEigenLayer(eigenLayerCommunityMultisig, eigenLayerOperationsMultisig, eigenLayerPauserMultisig, strategyConfigs);

        // deploy proxy admin for ability to upgrade proxy contracts
        eigenDAProxyAdmin = new ProxyAdmin();

        // deploy pauser registry
        {
            address[] memory pausers = new address[](2);
            pausers[0] = eigenDAPauser;
            pausers[1] = eigenDACommunityMultisig;
            eigenDAPauserReg = new PauserRegistry(pausers, eigenDACommunityMultisig);
        }

        emptyContract = new EmptyContract();

        // hard-coded inputs

        /**
         * First, deploy upgradeable proxy contracts that **will point** to the implementations. Since the implementation contracts are
         * not yet deployed, we give these proxies an empty contract as the initial implementation, to act as if they have no code.
         */
        eigenDAServiceManager = EigenDAServiceManager(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenDAProxyAdmin), ""))
        );
        pubkeyCompendium = new BLSPublicKeyCompendium();
        registryCoordinator = BLSRegistryCoordinatorWithIndices(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenDAProxyAdmin), ""))
        );
        blsPubkeyRegistry = IBLSPubkeyRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenDAProxyAdmin), ""))
        );
        indexRegistry = IIndexRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenDAProxyAdmin), ""))
        );
        stakeRegistry = IStakeRegistry(
            address(new TransparentUpgradeableProxy(address(emptyContract), address(eigenDAProxyAdmin), ""))
        );

        // Second, deploy the *implementation* contracts, using the *proxy contracts* as inputs
        {
            stakeRegistryImplementation = new StakeRegistry(
                registryCoordinator,
                strategyManager,
                eigenDAServiceManager
            );

            // set up a quorum with each strategy that needs to be set up
            uint96[] memory minimumStakeForQuourm = new uint96[](numStrategies);
            IVoteWeigher.StrategyAndWeightingMultiplier[][] memory strategyAndWeightingMultipliers = new IVoteWeigher.StrategyAndWeightingMultiplier[][](numStrategies);
            for (uint i = 0; i < numStrategies; i++) {
                strategyAndWeightingMultipliers[i] = new IVoteWeigher.StrategyAndWeightingMultiplier[](1);
                strategyAndWeightingMultipliers[i][0] = IVoteWeigher.StrategyAndWeightingMultiplier({
                    strategy: deployedStrategyArray[i],
                    multiplier: 1 gwei
                });
            }

            eigenDAProxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(stakeRegistry))),
                address(stakeRegistryImplementation),
                abi.encodeWithSelector(
                    StakeRegistry.initialize.selector,
                    minimumStakeForQuourm,
                    strategyAndWeightingMultipliers
                )
            );
        }

        registryCoordinatorImplementation = new BLSRegistryCoordinatorWithIndices(
            slasher,
            eigenDAServiceManager,
            stakeRegistry,
            blsPubkeyRegistry,
            indexRegistry
        );
        
        {
            IBLSRegistryCoordinatorWithIndices.OperatorSetParam[] memory operatorSetParams = new IBLSRegistryCoordinatorWithIndices.OperatorSetParam[](numStrategies);
            for (uint i = 0; i < numStrategies; i++) {
                // hard code these for now
                operatorSetParams[i] = IBLSRegistryCoordinatorWithIndices.OperatorSetParam({
                    maxOperatorCount: 10000,
                    kickBIPsOfOperatorStake: 15000,
                    kickBIPsOfAverageStake: 5000,
                    kickBIPsOfTotalStake: 100
                });
            }
            eigenDAProxyAdmin.upgradeAndCall(
                TransparentUpgradeableProxy(payable(address(registryCoordinator))),
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

        eigenDAProxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(blsPubkeyRegistry))),
            address(blsPubkeyRegistryImplementation)
        );

        indexRegistryImplementation = new IndexRegistry(
            registryCoordinator
        );

        eigenDAProxyAdmin.upgrade(
            TransparentUpgradeableProxy(payable(address(indexRegistry))),
            address(indexRegistryImplementation)
        );

        eigenDAServiceManagerImplementation = new EigenDAServiceManager(
            registryCoordinator,
            strategyManager,
            delegation,
            slasher,
            IPaymentManager(address(0))
        );

        // Third, upgrade the proxy contracts to use the correct implementation contracts and initialize them.
        eigenDAProxyAdmin.upgradeAndCall(
            TransparentUpgradeableProxy(payable(address(eigenDAServiceManager))),
            address(eigenDAServiceManagerImplementation),
            abi.encodeWithSelector(
                EigenDAServiceManager.initialize.selector,
                eigenDAPauserReg,
                eigenDACommunityMultisig,
                0,
                eigenDACommunityMultisig
            )
        );

        blsOperatorStateRetriever = new BLSOperatorStateRetriever(
            registryCoordinator
        );
    }
}
