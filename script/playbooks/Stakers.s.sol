// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@eigenlayer/contracts/strategies/StrategyBase.sol";
import "../utils/PlaygroundAVSConfigParser.sol";
import "../utils/Utils.sol";
import "./Operators.s.sol";

contract Stakers is Script, PlaygroundAVSConfigParser {
    function  allocateTokensToStakersAndDelegateToOperator(
        string memory avsConfigFile
    ) external {

        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );


        /* parsing avsConfigFile for stakers */
        Staker[] memory stakers;
        // we are setting number of strategies to 1
        // TODO: change 1 to length of the dummyTokenStrat field in EigenLayer struct after array format is adopted 
        stakers = parseStakersFromConfigFile(avsConfigFile, 1);


        /* allocation of token to stakers */
        // TODO: change 1 to length of the dummyTokenStrat field in EigenLayer struct after array format is adopted 
        address[] memory strategyAddresses = new address[](1);
        strategyAddresses[0] = address(contracts.eigenlayer.dummyTokenStrat);
        allocateTokenToStakers(stakers, strategyAddresses);

        // parsing avsConfigFile for operators
        Operator[] memory operators = parseOperatorsFromConfigFile(avsConfigFile);

        // stakers delegating to the operators
        // delgateToOperators(stakers, operators, contracts);
    }


    // function  unstakeFromEigen(
    //     string memory avsConfigFile
    // ) external {
    //     // queue withdrawal from EigenLayer

    // }


    function allocateTokenToStakers(
        Staker[] memory stakers,
        address[] memory strategyAddresses
    ) public {
        /* collect all the staker addresses in one array */
        address[] memory stakerAddresses = new address[](stakers.length);
        for (uint i = 0; i < stakers.length; i++) {
            stakerAddresses[i] = stakers[i].addr;
        }

        // For each strategy, allocate the corresponding tokens associated to stakers
        for (uint i = 0; i < strategyAddresses.length; i++) {
            /* 
                collect the amount of tokens allocated to each staker for the token 
                corresponding to strategy i 
            */
            uint256[] memory tokenAllocatedToStakers = new uint256[](
                stakers.length
            );
            for (uint j = 0; j < stakers.length; j++) {
                tokenAllocatedToStakers[j] = stakers[j].stakeAllocated[i];
            }

            // TODO: access Anvil private key instead of hardcoding it
            vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
            _allocateNew(
                strategyAddresses[i],
                stakerAddresses,
                tokenAllocatedToStakers
            );
            vm.stopBroadcast();
        }
    }



    function delgateToOperators(
        Staker[] memory stakers,
        Operator[] memory operators,
        Contracts memory contracts
    ) public {

        // Deposit stakers into EigenLayer and delegate to operators
        for (uint256 i = 0; i < stakers.length; i++) {
            vm.startBroadcast(stakers[i].privateKey);
            // TODO: change 1 to length of the dummyTokenStrat field after array format is adopted 
            for (uint j = 0; j < 1; j++) {
                if (stakers[i].stakeAllocated[j] > 0) {
                    // TODO: change the following call to strategy after array format is adopted
                    contracts.eigenlayer.dummyTokenStrat.underlyingToken().approve(
                        address(contracts.eigenlayer.strategyManager),
                        stakers[i].stakeAllocated[j]
                    );

                    /* 
                        Staker i deposits `stakeAllocated` amount of `token` into the specified 
                        `strategy`
                    */
                    contracts.eigenlayer.strategyManager.depositIntoStrategy(
                        contracts.eigenlayer.dummyTokenStrat,
                        contracts.eigenlayer.dummyTokenStrat.underlyingToken(),
                        stakers[i].stakeAllocated[j]
                    );
                }
            }

            // staker i is calling delegation manager to delegate its assets to some operator i
            contracts.eigenlayer.delegationManager.delegateTo(operators[i].addr);
            vm.stopBroadcast();
        }
    }


    // STATUS PRINTER FUNCTIONS
    function printStatusOfStakersFromConfigFile(
        string memory avsConfigFile
    ) external {
        // TODO: change 1 to length of the dummyTokenStrat field in EigenLayer struct after array format is adopted 
        Staker[] memory stakers = parseStakersFromConfigFile(
            avsConfigFile, 
            1
        );

        for (uint256 i = 0; i < stakers.length; i++) {
            emit log_named_uint("PRINTING STATUS OF STAKER", i);
            printStakerStatus(stakers[i].addr);
            emit log("--------------------------------------------------");
        }
    }

    function printStakerStatus(address stakerAddr) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        emit log_named_address("staker address", stakerAddr);
        
        bool isDelegated = contracts
            .eigenlayer
            .delegationManager
            .isDelegated(stakerAddr);
        emit log_named_string(
            "staker has delegated to some operator",
            convertBoolToString(isDelegated)
        );


        address operatorDelegatedTo = contracts
            .eigenlayer
            .delegationManager
            .delegatedTo(stakerAddr);
        emit log_named_address(
            "staker has delegated to the operator:",
            operatorDelegatedTo
        );


    }
}
