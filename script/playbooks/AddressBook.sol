// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity =0.8.12;

// import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
// import "@eigenlayer/contracts/core/DelegationManager.sol";

// import "@eigenlayer/contracts/core/StrategyManager.sol";
// import "@eigenlayer/contracts/strategies/StrategyBase.sol";
// import "@eigenlayer/contracts/core/Slasher.sol";

// // Can't use the interface when we need access to state variables
// import "@playground-avs/core/PlaygroundAVSServiceManagerV1.sol";

// import "forge-std/Test.sol";
// import "forge-std/Script.sol";
// import "forge-std/StdJson.sol";

// contract ContractsAddressBook is Script, DSTest {
//     Vm cheats = Vm(HEVM_ADDRESS);

//     string _deployOutputPath = "script/output/playgroundAVS_deploy_output.json";
//     string deployOutputData = vm.readFile(_deployOutputPath);

//     PlaygroundAVSServiceManagerV1 playgroundAVSServiceManager =
//         PlaygroundAVSServiceManagerV1(
//             stdJson.readAddress(
//                 deployOutputData,
//                 ".playgroundAVSServiceManager"
//             )
//         );
//     IDelegationManager delegationManager = playgroundAVSServiceManager.delegationManager();
//     StrategyManager public strategyManager;
//     IERC20 public weth;
//     StrategyBase public wethStrat;
//     IERC20 public eigen;
//     StrategyBase public eigenStrat;

//     uint256[] memory operatorPrivateKeys = stdJson.readUintArray(configData, ".operatorPrivateKeys");
//     address[] memory operators = new address[](operatorPrivateKeys.length);
//     for (uint i = 0; i < operators.length; i++) {
//         operators[i] = vm.addr(operatorPrivateKeys[i]);
//     }
// }
