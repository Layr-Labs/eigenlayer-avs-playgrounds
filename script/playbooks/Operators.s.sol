// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "../utils/PlaygroundAVSConfigParser.sol";

contract Operators is Script, PlaygroundAVSConfigParser {
    // default forge script entrypoint. Run with
    // forge script script/playbooks/Operators.s.sol --sig "run(string memory input)" --rpc-url $RPC_URL playground_avs_input --broadcast
    function run(string memory input) external {
        Contracts memory contracts;
        Operator[] memory operators;
        (contracts, operators) = parseConfigFile(input);

        // registerOperatorsWithEigenlayer(operators, contracts);
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
}
