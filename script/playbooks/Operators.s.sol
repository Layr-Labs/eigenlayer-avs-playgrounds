// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "./AddressBook.sol";

contract BecomeOperator is Script, DSTest, ContractsAddressBook {

    string _operatorsConfigFile = "./operators_config.json";
    string operatorsConfigData = vm.readFile(_operatorsConfigFile);

    function run() external {
        vm.broadcast(msg.sender);
        delegationManager.registerAsOperator(IDelegationTerms(msg.sender));
    }

    function getOperators() external view returns (address[] memory) {
        address[] memory operatorPrivateKeys = stdJson.readUintArray(configData, ".operatorPrivateKeys");
        address[] memory operators = new address[](operatorPrivateKeys.length);
        for (uint i = 0; i < operators.length; i++) {
            operators[i] = vm.addr(operatorPrivateKeys[i]);
        }
    }

    function registerWithEigenlayer() {
        for (uint256 i = 0; i < operatorPrivateKeys.length; i++) {
            vm.broadcast(operatorPrivateKeys[i]);
            delegation.registerAsOperator(IDelegationTerms(operators[i]));
        }
    }
}
