// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "../utils/PlaygroundAVSConfigParser.sol";
import "../utils/Utils.sol";

import "@eigenlayer/contracts/interfaces/IRegistryCoordinator.sol";

contract PrintAVSStatus is Script, DSTest, PlaygroundAVSConfigParser, Utils {
    // default forge script entrypoint. Run with
    // forge script script/playbooks/PrintAVSStatus.s.sol --sig "run(string memory input)" --broadcast -vvvv --rpc-url $RPC_URL playgroundAVS_input
    function run(string memory input) external {
        Contracts memory contracts;
        Operator[] memory operators;
        (contracts, operators) = parseConfigFile(input);

        printOperatorStatus(operators[0], contracts);
    }

    function printOperatorStatus(
        Operator memory operator,
        Contracts memory contracts
    ) public {
        emit log_named_uint("operator private key", operator.privateKey);
        emit log_named_address("operator address", operator.addr);
        emit log_named_uint(
            "dummy token balance",
            contracts.tokens.dummyToken.balanceOf(operator.addr)
        );
        bool isEigenlayerOperator = contracts
            .eigenlayer
            .delegationManager
            .isOperator(operator.addr);
        emit log_named_string(
            "operator is opted in to eigenlayer",
            convertBoolToString(isEigenlayerOperator)
        );
        bool canBeSlashedByPlaygroundAVS = contracts
            .eigenlayer
            .slasher
            .canSlash(
                operator.addr,
                address(contracts.playgroundAVS.serviceManager)
            );
        emit log_named_string(
            "operator is opted in to playgroundAVS (aka can be slashed)",
            convertBoolToString(canBeSlashedByPlaygroundAVS)
        );
        IRegistryCoordinator.Operator memory operatorFromRegistry = contracts
            .playgroundAVS
            .registryCoordinator
            .getOperator(operator.addr);
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
        bool isFrozen = contracts.eigenlayer.slasher.isFrozen(operator.addr);
        emit log_named_string(
            "operator is frozen",
            convertBoolToString(isFrozen)
        );}
}
