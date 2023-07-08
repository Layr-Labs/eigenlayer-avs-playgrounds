// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;


import "@eigenlayer/contracts/strategies/StrategyBase.sol";
import "../utils/PlaygroundAVSConfigParser.sol";
import "../utils/Utils.sol";


contract Stakers is Script,PlaygroundAVSConfigParser, Utils {

    function run(string memory input) external {

        Staker[] memory stakers;
        address[] memory strategyAddresses;
        
        // parsing input
        (stakers, strategyAddresses) = parseConfigFileForStaker(input);

        // allocation of token
        allocateTokenOnChain(stakers, strategyAddresses);
    }


    function allocateTokenOnChain(
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
}