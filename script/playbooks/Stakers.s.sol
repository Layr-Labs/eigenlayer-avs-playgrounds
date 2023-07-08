// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;


import "@eigenlayer/contracts/strategies/StrategyBase.sol";
import "../utils/PlaygroundAVSConfigParser.sol";


contract Stakers is Script,PlaygroundAVSConfigParser {



    function run(string memory input) external {

        Staker[] memory stakers;
        stakers = parseConfigFileForStaker(input);
        // string memory avsConfig = readInput(input);

        // /* =========== getting the staker private keys and address ================= */
        // uint256[] memory stakerPrivateKeys = stdJson.readUintArray(avsConfig, ".stakerPrivateKeys");
        // // emit log_bytes32(bytes32(stakerPrivateKeys[1]));
        // Staker[] memory stakers = getStakersFromPrivateKeysAndAddr(stakerPrivateKeys);


        // /* =========== getting the staker private keys and address ================= */
        // allocateStake(stakers, avsConfig);

        // emit log_bytes32(bytes32(stakers[0].privateKey));

    }

    // // @notice This function is called to get the public addresses of the stakers whose private keys are mentioned in config file
    // // @return This returns the public addresses of the stakers
    // function getStakersFromPrivateKeysAndAddr(uint256[] memory stakerPrivateKeys) public pure returns (Staker[] memory stakers) {
    //     // initializing the array
    //     stakers = new Staker[](stakerPrivateKeys.length);
        
    //     // filling the array
    //     for (uint i = 0; i < stakers.length; i++) {
    //         stakers[i].addr = vm.addr(stakerPrivateKeys[i]);
    //     }
    // }


    // // @notice This function is called to obtain the ETH that is restaked by each staker
    // function allocateStake(Staker[] memory stakers, string memory avsConfig) public {

    //     // get staker addresses
    //     address[] memory stakerAddresses = new address[](stakers.length);
    //     for (uint i = 0; i < stakers.length; i++) {
    //         stakerAddresses = stakers[i].addr;
    //     }

    //     // stakerTokenAmount[i][j] is the amount of token i that staker j will receive
    //     bytes memory stakerTokenAmountsRaw = stdJson.parseRaw(
    //         avsConfig,
    //         ".stake"
    //     );
    //     // emit log_bytes(stakerTokenAmountsRaw);
    //     uint256[][] memory stakerTokenAmounts = abi.decode(
    //         stakerTokenAmountsRaw,
    //         (uint[][])
    //     );

    //     // emit log_bytes32(bytes32(stakerTokenAmounts[0][0]));
    //     // uint256[] memory stake = stdJson.readUintArray(avsConfig, ".stake");
    //     // emit log_bytes32(bytes32(stake[0]));

    //     /* get the strategy addresses */
    //     uint256[] memory strategyAddresses = stdJson.readUintArray(avsConfig, ".strategyAddresses");
    //     StrategyBase[] memory strategies = new StrategyBase[](strategyAddresses.length);


    //     // // al the array
    //     // for (uint i = 0; i < stakers.length; i++) {
    //     //     uint256[] memory strategyStake = new uint256[](numStrategies);
    //     //     for (uint j = 0; j < stakers.length; j++) {
    //     //         strategyStake[j] = stakerTokenAmounts[i][j];
    //     //     }
    //     //     stakers[i].stake = strategyStake;
    //     // }

    //     // Allocate tokens to stakers
    //     for (uint i = 0; i < strategies.length; i++) {
    //         vm.startBroadcast();
    //         for (uint j = 0; j < stakers.length; j++) {
    //             _allocate(
    //                 IERC20(strategies[i].underlyingToken()),
    //                 stakers,
    //                 stakerTokenAmounts[i]
    //             );
    //         }
    //         vm.stopBroadcast();
    //     }

    //     // return stakerETHAmounts;
    // }

    // // function allocate() {
    // //     // Allocate eth to stakers and operators
    // //     _allocate(
    // //         IERC20(address(0)),
    // //         stakers,
    // //         stakerETHAmounts
    // //     );
    // // }

}