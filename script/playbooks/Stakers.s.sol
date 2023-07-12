// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@eigenlayer/contracts/strategies/StrategyBase.sol";
import "@eigenlayer/contracts/interfaces/IStrategyManager.sol";

import "../utils/PlaygroundAVSConfigParser.sol";
import "../utils/Utils.sol";
import "./Operators.s.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Stakers is Script, PlaygroundAVSConfigParser {

    // @TODO: see if we can make them memory
    mapping(address => IStrategy[]) public allStrategiesWhereWithdrawalHappening;
    mapping(address => uint256[]) public sharesInStrategiesWhereWithdrawalHappening;

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
        delgateToOperators(stakers, operators, contracts);
    }


    function  queueWithdrawalFromEigenLayer(
        string memory avsConfigFile,
        string memory queuedWithdrawalOutputFile
    ) external {

        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );


        /* parsing avsConfigFile for info on stakers that are currently restaked in EigenLayer */
        Staker[] memory stakersCurrentlyRestakedOnEigenLayer;
        // we are setting number of strategies to 1
        // TODO: change 1 to length of the dummyTokenStrat field in EigenLayer struct after array format is adopted 
        stakersCurrentlyRestakedOnEigenLayer = parseStakersFromConfigFile(avsConfigFile, 1);
        // emit log_address(stakersCurrentlyRestakedOnEigenLayer[0].addr);

        /* parsing avsConfigFile for stakers that are to be withdrawn */
        Staker[] memory stakersToBeWithdrawn;
        /* getting information on which stakers have to be withdrawn from the json file */
        stakersToBeWithdrawn = parseConfigFileForStakersToBeWithdrawn(
                                        avsConfigFile, 
                                        stakersCurrentlyRestakedOnEigenLayer
                                        );

        // emit log_address(stakersToBeWithdrawn[0].addr);
        
        queueWithdrawalFromEigenLayer(contracts, stakersToBeWithdrawn);
        uint32 withdrawalStartBlock = parseBlockNumberFromQueuedWithdrawal(queuedWithdrawalOutputFile);
        // notifyService(contracts, stakersToBeWithdrawn);

        // // get middlewareTimesIndex index
        // /* 
        //     TODO: change it to also consider multiple AVS scenario. Right now it is okay for 
        //     single AVS case.
        // */
        // uint256 middlewareTimesIndex = 0;
        // for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {
        //     // TODO: following method works only if there is only one pending withdrawal
        //     // because every time a new queue withdrawal happens, the latest file in 
        //     // broadcast folder changes. 
        //     completeQueuedWithdrawal(
        //                 contracts,
        //                 stakersToBeWithdrawn[i],
        //                 withdrawalStartBlock,
        //                 uint256 middlewareTimesIndex 
        //     );
        // }

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

    function queueWithdrawalFromEigenLayer (
        Contracts memory contracts,
        Staker[] memory stakersToBeWithdrawn
    ) public {
        
        for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {
            vm.startBroadcast(stakersToBeWithdrawn[i].privateKey);

            // get details on the staker's shares and the strategy
            (IStrategy[] memory strategies, uint256[] memory shares) = contracts.eigenlayer.strategyManager.getDeposits(
                            stakersToBeWithdrawn[i].addr
                        );

            // queue withdrawal from EigenLayer
            /* 
                @todo for now I have hardcoded the index of the strategy to be removed to be 0.
                But this needs to be passed in the json.
            */
            uint256[] memory strategyIndexes = new uint256[](1);
            strategyIndexes[0] = 0;
            bytes32 withdrawalRoot;
            withdrawalRoot = contracts.eigenlayer.strategyManager.queueWithdrawal(
                                    strategyIndexes,
                                    strategies,
                                    shares,
                                    // set the withdrawer to be staker itself
                                    stakersToBeWithdrawn[i].addr,
                                    true
                                );

            vm.stopBroadcast();


            allStrategiesWhereWithdrawalHappening[stakersToBeWithdrawn[i].addr] = strategies;
            sharesInStrategiesWhereWithdrawalHappening[stakersToBeWithdrawn[i].addr] = shares;

        }

    }


    function notifyService(
        Contracts memory contracts,
        Staker[] memory stakersToBeWithdrawn
    ) public { 

        /* getting the address of the operators to whom the stakers who are withdrawing are delegating to */
        address[] memory addressOfOperatorsDelegatedTo = new address[](stakersToBeWithdrawn.length);
        for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {
            vm.startBroadcast();
            addressOfOperatorsDelegatedTo[i] = contracts
                                                .eigenlayer
                                                .delegationManager
                                                .delegatedTo(stakersToBeWithdrawn[i].addr);
            vm.stopBroadcast();
        }


        /* getting the IDs of the operators */
        bytes32[] memory idsOfOperatorDelegatedTo = new bytes32[](stakersToBeWithdrawn.length);
        for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {
            vm.startBroadcast();
            idsOfOperatorDelegatedTo[i] = contracts
                                        .playgroundAVS
                                        .registryCoordinator
                                        .getOperator(addressOfOperatorsDelegatedTo[i])
                                        .operatorId;
            vm.stopBroadcast();
        }


        /* setting the element indices in the linked list _operatorToWhitelistedContractsByUpdate */
        uint256[] memory prevElementArray = new uint256[](stakersToBeWithdrawn.length);
        // @TODO change this to more general. For now, there is only one middleware
        for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {
            prevElementArray[i] = 0;
        }


        // call AVS's StakeRegistry for notifying the intention to withdraw
        vm.startBroadcast();
        contracts.playgroundAVS.registryCoordinator.stakeRegistry().updateStakes(
                                                                                addressOfOperatorsDelegatedTo,
                                                                                idsOfOperatorDelegatedTo,
                                                                                prevElementArray
                                                                            );
        vm.stopBroadcast();

    }


    function completeQueuedWithdrawal(
        Contracts memory contracts,
        Staker memory stakerWithdrawing,
        uint32 withdrawalStartBlock,
        uint256 middlewareTimesIndex
    ) public {

        /* 
            creating WithdrawerAndNonce
        */
        IStrategyManager.WithdrawerAndNonce memory withdrawerAndNonce;
        withdrawerAndNonce.withdrawer = stakerWithdrawing.addr;
        /* 
            TODO: ensure that there is only one withdrawal, otherwise numWithdrawalsQueued 
            doesn't work with multiple pending queuedWithdrawal. Need to notify 
            On-chain team about this.
        */
        vm.startBroadcast();
        withdrawerAndNonce.nonce = uint96(StrategyManager(address(contracts
                                            .eigenlayer
                                            .strategyManager))
                                            .numWithdrawalsQueued(stakerWithdrawing.addr));
        vm.stopBroadcast();


        /* 
            creating queuedWithdrawal
        */
        IStrategyManager.QueuedWithdrawal memory queuedWithdrawal;
        queuedWithdrawal.strategies = allStrategiesWhereWithdrawalHappening[stakerWithdrawing.addr];
        queuedWithdrawal.shares = sharesInStrategiesWhereWithdrawalHappening[stakerWithdrawing.addr];
        queuedWithdrawal.depositor = stakerWithdrawing.addr;
        queuedWithdrawal.withdrawerAndNonce = withdrawerAndNonce;
        queuedWithdrawal.withdrawalStartBlock = withdrawalStartBlock;


        // get all the underlying tokens in the strategies
        IERC20[] memory tokens = new IERC20[](allStrategiesWhereWithdrawalHappening[stakerWithdrawing.addr].length);
        for (uint i = 0; i < allStrategiesWhereWithdrawalHappening[stakerWithdrawing.addr].length; i++) {
            tokens[i] = allStrategiesWhereWithdrawalHappening[stakerWithdrawing.addr][i].underlyingToken();
        }

        bool receiveAsTokens = true;

        // complete the queued withdrawal transaction 
        vm.startBroadcast(stakerWithdrawing.privateKey);
        contracts.eigenlayer.strategyManager.completeQueuedWithdrawal(queuedWithdrawal, 
                                            tokens, 
                                            middlewareTimesIndex, 
                                            receiveAsTokens);
        vm.stopBroadcast();
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
