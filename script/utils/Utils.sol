// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@eigenlayer/contracts/interfaces/IRegistryCoordinator.sol";
import "@eigenlayer/contracts/strategies/StrategyBase.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract Utils is Script {
    function _allocate(
        IERC20 token,
        address[] memory tos,
        uint256[] memory amounts
    ) internal {
        for (uint256 i = 0; i < tos.length; i++) {
            if (token == IERC20(address(0))) {
                payable(tos[i]).transfer(amounts[i]);
            } else {
                token.transfer(tos[i], amounts[i]);
            }
        }
    }

    function _allocateNew(
        address strategyAddress,
        address[] memory tos,
        uint256[] memory amounts
    ) internal {
        for (uint256 i = 0; i < tos.length; i++) {
            IERC20 underlyingToken = StrategyBase(strategyAddress)
                .underlyingToken();
            underlyingToken.transfer(tos[i], amounts[i]);
        }
    }

    function convertBoolToString(
        bool input
    ) public pure returns (string memory) {
        if (input) {
            return "true";
        } else {
            return "false";
        }
    }

    function convertOperatorStatusToString(
        IRegistryCoordinator.OperatorStatus operatorStatus
    ) public pure returns (string memory) {
        if (
            operatorStatus ==
            IRegistryCoordinator.OperatorStatus.NEVER_REGISTERED
        ) {
            return "NEVER_REGISTERED";
        } else if (
            operatorStatus == IRegistryCoordinator.OperatorStatus.REGISTERED
        ) {
            return "REGISTERED";
        } else if (
            operatorStatus == IRegistryCoordinator.OperatorStatus.DEREGISTERED
        ) {
            return "DEREGISTERED";
        } else {
            return "UNKNOWN";
        }
    }

    // Forge scripts best practice: https://book.getfoundry.sh/tutorials/best-practices#scripts
    function readInput(
        string memory inputFileName
    ) internal view returns (string memory) {
        string memory inputDir = string.concat(
            vm.projectRoot(),
            "/script/input/"
        );
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(inputFileName, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }

    function readOutput(
        string memory outputFileName
    ) internal view returns (string memory) {
        string memory inputDir = string.concat(
            vm.projectRoot(),
            "/script/output/"
        );
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(outputFileName, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }

    function writeOutput(
        string memory outputJson,
        string memory outputFileName
    ) internal {
        string memory outputDir = string.concat(
            vm.projectRoot(),
            "/script/output/"
        );
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory outputFilePath = string.concat(
            outputDir,
            chainDir,
            outputFileName,
            ".json"
        );
        vm.writeJson(outputJson, outputFilePath);
    }
}
