// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;


import "@eigenlayer/contracts/strategies/StrategyBase.sol";
import "../utils/PlaygroundAVSConfigParser.sol";
import "../utils/Utils.sol";
import "./Operators.s.sol";


contract Stakers is Script, PlaygroundAVSConfigParser {

    function run(string memory input) external {

        // parsing input for stakers
        Staker[] memory stakers;
        address[] memory strategyAddresses;
        (stakers, strategyAddresses) = parseConfigFileForStaker(input);

        // allocation of token to stakers
        allocateTokenToStakers(stakers, strategyAddresses);

        // parsing input for operators 
        Contracts memory contracts;
        Operator[] memory operators;
        (contracts, operators) = parseConfigFile(input);

        // stakers delegating to the operators

    }


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
            uint256[] memory tokenAllocatedToStakers = new uint256[](stakers.length);
            for (uint j = 0; j < stakers.length; j++) {
                tokenAllocatedToStakers[j] = stakers[j].stakeAllocated[i];
            }
            vm.startBroadcast();
            _allocateNew(
                strategyAddresses[i],
                stakerAddresses,
                tokenAllocatedToStakers
            );
            vm.stopBroadcast();
        }
    }

//     function delgateToOperators(
//         Staker[] memory stakers, 
//         Operators[] memory operator,
//         Contracts memory contracts,
//         address[] memory strategyAddress
//     ) public {

//         uint256[] memory stakerPrivateKeys = new uint256[](stakers.length);
        
//         // Deposit stakers into EigenLayer and delegate to operators
//         for (uint256 i = 0; i < stakerPrivateKeys.length; i++) {
//             vm.startBroadcast(stakerPrivateKeys[i]);
//             for (uint j = 0; j < strategyAddress.length; j++) {
//                 if (stakerTokenAmounts[j][i] > 0) {
//                     deployedStrategyArray[j].underlyingToken().approve(
//                         address(strategyManager),
//                         stakerTokenAmounts[j][i]
//                     );
//                     strategyManager.depositIntoStrategy(
//                         deployedStrategyArray[j],
//                         deployedStrategyArray[j].underlyingToken(),
//                         stakerTokenAmounts[j][i]
//                     );
//                 }
//             }
//             delegation.delegateTo(operators[i]);
//             vm.stopBroadcast();
//         }
//     }
}