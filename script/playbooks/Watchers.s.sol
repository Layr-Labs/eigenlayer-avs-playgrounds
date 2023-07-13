// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../utils/PlaygroundAVSConfigParser.sol";
import "@eigenlayer/contracts/middleware/BLSRegistryCoordinatorWithIndices.sol";
import "@eigenlayer/contracts/middleware/BLSPubkeyRegistry.sol";

contract Operators is Script, PlaygroundAVSConfigParser {
    // PUBLIC FUNCTIONS THAT READ FROM CONFIG FILES AND CALL INTERNAL FUNCTIONS

    function freezeOperatorsFromConfigFile(string memory avsConfigFile) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );

        freezeOperators(operators, contracts);
    }

    function freezeOperators(
        Operator[] memory operators,
        Contracts memory contracts
    ) internal {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.broadcast();
            contracts.playgroundAVS.serviceManager.freezeOperator(
                operators[i].ECDSAAddress
            );
        }
    }
}
