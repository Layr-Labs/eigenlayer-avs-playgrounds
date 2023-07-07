// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.9;

// import "@eigenlayer-scripts/middleware/DeployOpenEigenLayer.s.sol";

// import "@eigenlayer/contracts/permissions/PauserRegistry.sol";

// import "@eigenlayer/contracts/middleware/BLSPublicKeyCompendium.sol";
// import "@eigenlayer/contracts/middleware/BLSRegistryCoordinatorWithIndices.sol";
// import "@eigenlayer/contracts/middleware/BLSPubkeyRegistry.sol";
// import "@eigenlayer/contracts/middleware/IndexRegistry.sol";
// import "@eigenlayer/contracts/middleware/StakeRegistry.sol";

// import "@eigenlayer/test/mocks/EmptyContract.sol";

// import "../../src/core/PlaygroundAVSServiceManagerV1.sol";

// import "../PlaygroundAVSDeployer.s.sol";
// import "../EigenLayerUtils.s.sol";

// import "./ContractsAddressBook.sol";

// import "forge-std/Test.sol";

// import "forge-std/Script.sol";
// import "forge-std/StdJson.sol";

// // TODO: REVIEW AND FIX THIS ENTIRE SCRIPT

// // # To load the variables in the .env file
// // source .env

// // # To deploy and verify our contract
// // forge script script/playbooks/Scratch.s.sol --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
// contract Scratch is ContractsAddressBook {

//     function run() external {
//         emit log_named_address("playgroundAVSServiceManager", address(playgroundAVSServiceManager));

//     }
// }
