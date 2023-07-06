// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@eigenlayer-scripts/middleware/DeployOpenEigenLayer.s.sol";

import "@eigenlayer/contracts/permissions/PauserRegistry.sol";

import "@eigenlayer/contracts/middleware/BLSPublicKeyCompendium.sol";
import "@eigenlayer/contracts/middleware/BLSRegistryCoordinatorWithIndices.sol";
import "@eigenlayer/contracts/middleware/BLSPubkeyRegistry.sol";
import "@eigenlayer/contracts/middleware/IndexRegistry.sol";
import "@eigenlayer/contracts/middleware/StakeRegistry.sol";

import "@eigenlayer/test/mocks/EmptyContract.sol";

import "../src/core/EigenDAServiceManager.sol";
import "../src/libraries/EigenDAHasher.sol";

import "./EigenDADeployer.s.sol";
import "./EigenLayerUtils.s.sol";

import "forge-std/Test.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

// TODO: REVIEW AND FIX THIS ENTIRE SCRIPT

// # To load the variables in the .env file
// source .env

// # To deploy and verify our contract
// forge script script/SetUpEigenDA.s.sol:SetupEigenDA --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv

contract SetupEigenDA is EigenDADeployer, EigenLayerUtils {

    string deployConfigPath = "script/eigenda_deploy_config.json";

    // deploy all the EigenDA contracts. Relies on many EL contracts having already been deployed.
    function run() external {
        

        // READ JSON CONFIG DATA
        string memory config_data = vm.readFile(deployConfigPath);

        
        uint8 numStrategies = uint8(stdJson.readUint(config_data, ".numStrategies"));
        {
            address eigenLayerCommunityMultisig = msg.sender;
            address eigenLayerOperationsMultisig = msg.sender;
            address eigenLayerPauserMultisig = msg.sender;
            address eigenDACommunityMultisig = msg.sender;
            address eigenDAPauser = msg.sender;

            uint256 initialSupply = 1000 ether;
            address tokenOwner = msg.sender;
            // bytes memory parsedData = vm.parseJson(config_data);
            bool useDefaults = stdJson.readBool(config_data, ".useDefaults");
            if(!useDefaults) {
                eigenLayerCommunityMultisig = stdJson.readAddress(config_data, ".eigenLayerCommunityMultisig");
                eigenLayerOperationsMultisig = stdJson.readAddress(config_data, ".eigenLayerOperationsMultisig");
                eigenLayerPauserMultisig = stdJson.readAddress(config_data, ".eigenLayerPauserMultisig");
                eigenDACommunityMultisig = stdJson.readAddress(config_data, ".eigenDACommunityMultisig");
                eigenDAPauser = stdJson.readAddress(config_data, ".eigenDAPauser");

                initialSupply = stdJson.readUint(config_data, ".initialSupply");
                tokenOwner = stdJson.readAddress(config_data, ".tokenOwner");
            }


            vm.startBroadcast();

            _deployEigenDAAndEigenLayerContracts(
                eigenLayerCommunityMultisig,
                eigenLayerOperationsMultisig,
                eigenLayerPauserMultisig,
                eigenDACommunityMultisig,
                eigenDAPauser,
                numStrategies,
                initialSupply,
                tokenOwner
            );

            vm.stopBroadcast();
        }

        uint256[] memory stakerPrivateKeys = stdJson.readUintArray(config_data, ".stakerPrivateKeys");
        address[] memory stakers = new address[](stakerPrivateKeys.length);
        for (uint i = 0; i < stakers.length; i++) {
            stakers[i] = vm.addr(stakerPrivateKeys[i]);
        }
        uint256[] memory stakerETHAmounts = new uint256[](stakers.length);
        // 0.1 eth each
        for (uint i = 0; i < stakerETHAmounts.length; i++) {
            stakerETHAmounts[i] = 0.1 ether;
        }

        // stakerTokenAmount[i][j] is the amount of token i that staker j will receive
        bytes memory stakerTokenAmountsRaw = stdJson.parseRaw(config_data, ".stakerTokenAmounts");
        uint256[][] memory stakerTokenAmounts = abi.decode(stakerTokenAmountsRaw, (uint256[][]));

        uint256[] memory operatorPrivateKeys = stdJson.readUintArray(config_data, ".operatorPrivateKeys");
        address[] memory operators = new address[](operatorPrivateKeys.length);
        for (uint i = 0; i < operators.length; i++) {
            operators[i] = vm.addr(operatorPrivateKeys[i]);
        }
        uint256[] memory operatorETHAmounts = new uint256[](operators.length);
        // 5 eth each
        for (uint i = 0; i < operatorETHAmounts.length; i++) {
            operatorETHAmounts[i] = 5 ether;
        }

        vm.startBroadcast();

        // Allocate eth to stakers and operators
        _allocate(
            IERC20(address(0)),
            stakers,
            stakerETHAmounts
        );

        _allocate(
            IERC20(address(0)),
            operators,
            operatorETHAmounts
        );

        // Allocate tokens to stakers
        for (uint8 i = 0; i < numStrategies; i++) {
            _allocate(
                IERC20(deployedStrategyArray[i].underlyingToken()),
                stakers,
                stakerTokenAmounts[i]
            );
        }

        {
            IStrategy[] memory strategies = new IStrategy[](numStrategies);
            for (uint8 i = 0; i < numStrategies; i++) {
                strategies[i] = deployedStrategyArray[i];
            }
            strategyManager.addStrategiesToDepositWhitelist(strategies);
        }

        vm.stopBroadcast();

        // Register operators with EigenLayer
        for (uint256 i = 0; i < operatorPrivateKeys.length; i++) {
            vm.broadcast(operatorPrivateKeys[i]);
            delegation.registerAsOperator(IDelegationTerms(operators[i]));
        }

        // Deposit stakers into EigenLayer and delegate to operators
        for (uint256 i = 0; i < stakerPrivateKeys.length; i++) {
            vm.startBroadcast(stakerPrivateKeys[i]);
            for (uint j = 0; j < numStrategies; j++) {
                if(stakerTokenAmounts[j][i] > 0) {
                    deployedStrategyArray[j].underlyingToken().approve(address(strategyManager), stakerTokenAmounts[j][i]);
                    strategyManager.depositIntoStrategy(
                        deployedStrategyArray[j],
                        deployedStrategyArray[j].underlyingToken(),
                        stakerTokenAmounts[j][i]
                    );
                }
            }
            delegation.delegateTo(operators[i]);
            vm.stopBroadcast();
        }

        string memory output = "eigenDA deployment output";
        vm.serializeAddress(output, "eigenDAServiceManager", address(eigenDAServiceManager));
        vm.serializeAddress(output, "blsOperatorStateRetriever", address(blsOperatorStateRetriever));

        string memory finalJson = vm.serializeString(output, "object", output);

        vm.writeJson(finalJson, "./script/output/eigenda_deploy_output.json");        
    }
}
