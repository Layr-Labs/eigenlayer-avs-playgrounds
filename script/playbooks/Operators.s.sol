// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "./AddressBook.sol";

contract Operators is Script, DSTest, AddressBook {

    struct Operator {
        address addr;
        uint256 privateKey;
    }

    // Forge scripts best practice: https://book.getfoundry.sh/tutorials/best-practices#scripts
    function readInput(string memory input) internal view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(input, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }
    // default forge script entrypoint. Run with
    // forge script script/playbooks/Operators.s.sol --sig "run(string memory input)" --broadcast -vvvv --rpc-url $RPC_URL playgroundAVS_input
    function run(string memory input) external {
        string memory avsConfig = readInput(input);
        uint256[] memory operatorPrivateKeys = stdJson.readUintArray(avsConfig, ".operatorPrivateKeys");
        Operator[] memory operators = getOperatorsFromPrivateKeys(operatorPrivateKeys);
        address playgroundAVSStrategyManagerV1 = stdJson.readAddress(avsConfig, ".playgroundAVSStrategyManagerV1");
        address dummyTokenStrat = stdJson.readAddress(avsConfig, ".strategies[0]");
        Contracts memory contracts = getContracts(playgroundAVSStrategyManagerV1, dummyTokenStrat);
        registerOperatorsWithEigenlayer(operators, contracts);
    }


    function getOperatorsFromPrivateKeys(uint256[] memory operatorPrivateKeys) public pure returns (Operator[] memory operators) {
        operators = new Operator[](operatorPrivateKeys.length);
        for (uint i = 0; i < operators.length; i++) {
            operators[i].privateKey = operatorPrivateKeys[i];
            operators[i].addr = vm.addr(operators[i].privateKey);
        }
    }

    function registerOperatorsWithEigenlayer(Operator[] memory operators, Contracts memory contracts) public {
        for (uint256 i = 0; i < operators.length; i++) {
            vm.broadcast(operators[i].privateKey);
            contracts.eigenlayer.delegationManager.registerAsOperator(IDelegationTerms(operators[i].addr));
        }
    }
}
