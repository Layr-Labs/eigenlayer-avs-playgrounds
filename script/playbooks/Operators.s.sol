// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../utils/PlaygroundAVSConfigParser.sol";
import "@eigenlayer/contracts/middleware/BLSRegistryCoordinatorWithIndices.sol";
import "@eigenlayer/contracts/middleware/BLSPubkeyRegistry.sol";

contract Operators is Script, PlaygroundAVSConfigParser {
    // PUBLIC FUNCTIONS THAT READ FROM CONFIG FILES AND CALL INTERNAL FUNCTIONS

    function registerOperatorsWithEigenlayerFromConfigFile(
        string memory avsConfigFile
    ) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );

        registerOperatorsWithEigenlayer(operators, contracts);
    }

    function registerOperatorsBN254KeysWithAVSPubkeyCompendiumFromConfigFile(
        string memory avsConfigFile
    ) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );
        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );
        registerOperatorsBN254KeysWithAVSPubkeyCompendium(operators, contracts);
    }

    function optOperatorsIntoSlashingByPlaygroundAVSFromConfigFile(
        string memory avsConfigFile
    ) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );
        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );
        optOperatorsIntoSlashingByPlaygroundAVS(operators, contracts);
    }

    function registerOperatorsWithPlaygroundAVSFromConfigFile(
        string memory avsConfigFile
    ) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );
        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );
        registerOperatorsWithPlaygroundAVS(operators, contracts);
    }

    function deregisterOperatorsWithPlaygroundAVSFromConfigFile(
        string memory avsConfigFile
    ) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );

        deregisterOperatorsWithPlaygroundAVS(operators, contracts);
    }

    // FUNCTIONALITY FUNCTIONS

    function registerOperatorsWithEigenlayer(
        Operator[] memory operators,
        Contracts memory contracts
    ) internal {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.broadcast(operators[i].ECDSAPrivateKey);
            contracts.eigenlayer.delegationManager.registerAsOperator(
                IDelegationTerms(operators[i].ECDSAAddress)
            );
        }
    }

    function registerOperatorsBN254KeysWithAVSPubkeyCompendium(
        Operator[] memory operators,
        Contracts memory contracts
    ) internal {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.startBroadcast(operators[i].ECDSAPrivateKey);
            // TODO(samlaf): create a github issue to eventually fix this typecasting ugliness
            //               what's even the point of having interfaces if we don't use them?
            // also probably want to make this registration function a separate thing that we can call early on
            BLSPubkeyRegistry(
                address(
                    BLSRegistryCoordinatorWithIndices(
                        address(contracts.playgroundAVS.registryCoordinator)
                    ).blsPubkeyRegistry()
                )
            ).pubkeyCompendium().registerBLSPublicKey(
                    operators[i].SchnorrSignatureOfECDSAAddress,
                    operators[i].SchnorrSignatureR,
                    operators[i].BN254G1PublicKey,
                    operators[i].BN254G2PublicKey
                );
            vm.stopBroadcast();
        }
    }

    function optOperatorsIntoSlashingByPlaygroundAVS(
        Operator[] memory operators,
        Contracts memory contracts
    ) internal {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.startBroadcast(operators[i].ECDSAPrivateKey);
            contracts.eigenlayer.slasher.optIntoSlashing(
                address(contracts.playgroundAVS.serviceManager)
            );
            vm.stopBroadcast();
        }
    }

    function registerOperatorsWithPlaygroundAVS(
        Operator[] memory operators,
        Contracts memory contracts
    ) internal {
        // we don't initialize it because we register with quorum 0 (first quorum)
        bytes memory quorumNumbers = new bytes(1);
        string memory socket = "NotNeededForPlaygroundAVS";
        for (uint256 i = 0; i < operators.length; i++) {
            bytes memory registrationData = abi.encode(
                operators[i].BN254G1PublicKey,
                socket
            );
            vm.startBroadcast(operators[i].ECDSAPrivateKey);
            contracts
                .playgroundAVS
                .registryCoordinator
                .registerOperatorWithCoordinator(
                    quorumNumbers,
                    registrationData
                );
            vm.stopBroadcast();
        }
    }

    function deregisterOperatorsWithPlaygroundAVS(
        Operator[] memory operators,
        Contracts memory contracts
    ) internal {
        bytes memory quorumNumbers = new bytes(1);
        // TODO: can we call this fct without specifying operators to swap?
        bytes32[] memory operatorIdsToSwap = new bytes32[](1);
        for (
            uint256 forwardIdx = 0;
            forwardIdx < operators.length;
            forwardIdx++
        ) {
            // deregistration is a bit clunky because
            // we deregister from the back to the front because
            // we get the operatorId from the registry
            uint256 backwardIdx = operators.length - 1 - forwardIdx;
            IRegistryCoordinator.Operator
                memory operatorFromRegistry = contracts
                    .playgroundAVS
                    .registryCoordinator
                    .getOperator(operators[backwardIdx].ECDSAAddress);
            operatorIdsToSwap[0] = operatorFromRegistry.operatorId;
            bytes memory deregistrationData = abi.encode(
                operators[backwardIdx].BN254G1PublicKey,
                operatorIdsToSwap
            );
            vm.startBroadcast(operators[backwardIdx].ECDSAPrivateKey);
            contracts
                .playgroundAVS
                .registryCoordinator
                .deregisterOperatorWithCoordinator(
                    quorumNumbers,
                    deregistrationData
                );
            vm.stopBroadcast();
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
            printOperatorStatus(operators[i].ECDSAAddress);
            emit log("--------------------------------------------------");
        }
    }

    // TODO(samlaf): also print whether BLS key was registered with BLS compendium
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
        uint delegatedShares = contracts
            .eigenlayer
            .delegationManager
            .operatorShares(operatorAddr, contracts.eigenlayer.dummyTokenStrat);
        emit log_named_uint(
            "delegated shares in dummyTokenStrat",
            delegatedShares
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
        emit log_named_string(
            "operator status in AVS registry",
            convertOperatorStatusToString(operatorFromRegistry.status)
        );
        emit log_named_bytes32(
            "   operatorId in AVS registry",
            operatorFromRegistry.operatorId
        );
        emit log_named_uint(
            "   operator fromTaskNumber in AVS registry",
            operatorFromRegistry.fromTaskNumber
        );
        bool isFrozen = contracts.eigenlayer.slasher.isFrozen(operatorAddr);
        emit log_named_string(
            "operator is frozen",
            convertBoolToString(isFrozen)
        );
    }
}
