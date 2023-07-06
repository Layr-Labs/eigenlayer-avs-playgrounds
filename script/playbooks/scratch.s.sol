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

import "../../src/core/PlaygroundServiceManagerV1.sol";

import "../PlaygroundAVSDeployer.s.sol";
import "../EigenLayerUtils.s.sol";

import "forge-std/Test.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

// TODO: REVIEW AND FIX THIS ENTIRE SCRIPT

// # To load the variables in the .env file
// source .env

// # To deploy and verify our contract
// forge script script/playbooks/scratch.s.sol:Scratch --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
contract Scratch is PlaygroundAVSDeployer, EigenLayerUtils {

    string deployConfigPath = "script/playgroundAVS_deploy_config.json";

    // deploy all the playgroundAVS contracts. Relies on many EL contracts having already been deployed.
    function run() external {
        
        // READ JSON CONFIG DATA
        string memory config_data = vm.readFile(deployConfigPath);

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
            emit log_named_uint('operators', operatorPrivateKeys[i]);
        }
        uint256[] memory operatorETHAmounts = new uint256[](operators.length);
        // 5 eth each
        for (uint i = 0; i < operatorETHAmounts.length; i++) {
            operatorETHAmounts[i] = 5 ether;
        }       
    }
}
