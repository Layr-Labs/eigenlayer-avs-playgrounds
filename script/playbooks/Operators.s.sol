// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../utils/PlaygroundAVSConfigParser.sol";

contract Operators is Script, PlaygroundAVSConfigParser {
    function registerOperatorsWithEigenlayerAndAvsFromConfigFile(
        string memory avsConfigFile
    ) external {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );

        registerOperatorsWithEigenlayer(operators, contracts);
        registerOperatorsWithPlaygroundAVS(operators, contracts);
    }

    function registerOperatorsWithEigenlayer(
        Operator[] memory operators,
        Contracts memory contracts
    ) public {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.broadcast(operators[i].privateKey);
            contracts.eigenlayer.delegationManager.registerAsOperator(
                IDelegationTerms(operators[i].addr)
            );
        }
    }

    function registerOperatorsWithPlaygroundAVS(
        Operator[] memory operators,
        Contracts memory contracts
    ) public {
        // TODO: we first need to call slasher.optIntoSlashing()
        bytes memory quorumNumbers = abi.encodePacked(uint256(1));
        string memory socket = "whatIsThis?";
        for (uint256 i = 0; i < operators.length; i++) {
            bytes memory registrationData = abi.encode(
                operators[i].blsPubKey,
                socket
            );
            vm.broadcast(operators[i].privateKey);
            contracts
                .playgroundAVS
                .registryCoordinator
                .registerOperatorWithCoordinator(
                    quorumNumbers,
                    registrationData
                );
        }
    }

    // STATUS PRINTER FUNCTIONS

    function printStatusOfOperatorsFromConfigFile(
        string memory avsConfigFile
    ) external {
        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );

        for (uint256 i = 0; i < operators.length; i++) {
            emit log_named_uint("PRINTING STATUS OF OPERATOR", i);
            printOperatorStatus(operators[i].addr);
            emit log("--------------------------------------------------");
        }
    }

    function printOperatorStatus(address operatorAddr) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );
        emit log_named_address("operator address", operatorAddr);
        emit log_named_uint(
            "dummy token balance",
            contracts.tokens.dummyToken.balanceOf(operatorAddr)
        );
        bool isEigenlayerOperator = contracts
            .eigenlayer
            .delegationManager
            .isOperator(operatorAddr);
        emit log_named_string(
            "operator is opted in to eigenlayer",
            convertBoolToString(isEigenlayerOperator)
        );
        bool canBeSlashedByPlaygroundAVS = contracts
            .eigenlayer
            .slasher
            .canSlash(
                operatorAddr,
                address(contracts.playgroundAVS.serviceManager)
            );
        emit log_named_string(
            "operator is opted in to playgroundAVS (aka can be slashed)",
            convertBoolToString(canBeSlashedByPlaygroundAVS)
        );
        IRegistryCoordinator.Operator memory operatorFromRegistry = contracts
            .playgroundAVS
            .registryCoordinator
            .getOperator(operatorAddr);
        emit log_named_bytes32(
            "operatorId from registry",
            operatorFromRegistry.operatorId
        );
        emit log_named_uint(
            "operator fromTaskNumber from registry",
            operatorFromRegistry.fromTaskNumber
        );
        emit log_named_string(
            "operator status from registry",
            convertOperatorStatusToString(operatorFromRegistry.status)
        );
        bool isFrozen = contracts.eigenlayer.slasher.isFrozen(operatorAddr);
        emit log_named_string(
            "operator is frozen",
            convertBoolToString(isFrozen)
        );
    }
}
