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
    Vm cheats = Vm(HEVM_ADDRESS);

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
        string memory avsConfigFile
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

        emit log_address(stakersToBeWithdrawn[0].addr);
        
        queueWithdrawalFromEigenLayer(contracts, stakersToBeWithdrawn);

    }

    function notifyServiceAboutWithdrawal(
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

        (uint32 withdrawalStartBlock, address[] memory arrDelegatedOperatorAddrForQueuedWithdrawals, bytes32[] memory withdrawalRoot) = parseBlockNumberAndOperatorDetailsFromQueuedWithdrawal(queuedWithdrawalOutputFile);
        
        // emit log_string("here1");
        notifyService(contracts, 
                    stakersToBeWithdrawn, 
                    arrDelegatedOperatorAddrForQueuedWithdrawals
                    );
    }


    function completeQueuedWithdrawalFromEigenLayer(
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

        
        (uint32 withdrawalStartBlock, address[] memory arrDelegatedOperatorAddrForQueuedWithdrawals, bytes32[] memory withdrawalRoot) = parseBlockNumberAndOperatorDetailsFromQueuedWithdrawal(queuedWithdrawalOutputFile);
        (address stakerToBeWithdrawn, address[] memory strategyAddresses, uint256[] memory shares) = parseQueuedWithdrawalDetails(queuedWithdrawalOutputFile);
        
        // TODO: get stakersToBeWithdrawn from above parsing of json file
        /* parsing avsConfigFile for stakers that are to be withdrawn */
        Staker[] memory stakersToBeWithdrawn;
        /* getting information on which stakers have to be withdrawn from the json file */
        stakersToBeWithdrawn = parseConfigFileForStakersToBeWithdrawn(
                                        avsConfigFile, 
                                        stakersCurrentlyRestakedOnEigenLayer
                                        );


        // emit log_string("here2");
        // get middlewareTimesIndex index
        /* 
            TODO: change it to also consider multiple AVS scenario. Right now it is okay for 
            single AVS case.
        */
        uint256 middlewareTimesIndex = 1;
        for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {
            // TODO: following method works only if there is only one pending withdrawal
            // because every time a new queue withdrawal happens, the latest file in 
            // broadcast folder changes. 
            completeQueuedWithdrawal(
                        contracts,
                        stakersToBeWithdrawn[i],
                        withdrawalStartBlock,
                        middlewareTimesIndex,
                        arrDelegatedOperatorAddrForQueuedWithdrawals[i],
                        strategyAddresses,
                        shares 
            );
        }
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
            contracts.eigenlayer.delegationManager.delegateTo(operators[i].ECDSAAddress);
            vm.stopBroadcast();
        }
    }

    function queueWithdrawalFromEigenLayer (
        Contracts memory contracts,
        Staker[] memory stakersToBeWithdrawn
    ) public {
        
        // TODO: change the json file input of this function to comply with multiple staker withdrawals
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

            // get an array of strategy addresses
            address[] memory strategyAddresses = new address[](strategies.length);
            for (uint j = 0; j < strategies.length; j++) {
                strategyAddresses[j] = address(strategies[j]);
            }

            // WRITE JSON DATA
            string memory parent_object = "parent object";

            string memory staker_withdrawing = "staker";
            string memory staker_withdrawing_output = vm.serializeAddress(
                staker_withdrawing,
                "staker_address",
                stakersToBeWithdrawn[i].addr
            );

            string memory withdrawal_strategies = "strategies";
            string memory withdrawal_strategies_output = vm.serializeAddress(
                withdrawal_strategies,
                "strategy_addresses",
                strategyAddresses
            );

            string memory withdrawal_strategies_shares = "shares";
            string memory withdrawal_strategies_shares_output = vm.serializeUint(
                withdrawal_strategies_shares,
                "shares",
                shares
            );

            // serialize all the data
            vm.serializeString(
                parent_object,
                staker_withdrawing,
                staker_withdrawing_output
            );

            vm.serializeString(
                parent_object,
                withdrawal_strategies,
                withdrawal_strategies_output
            );

            string memory finalJson = vm.serializeString(
                parent_object,
                withdrawal_strategies_shares,
                withdrawal_strategies_shares_output
            );

            writeOutput(finalJson, "queue_withdrawal_output");




        }

    }


    function notifyService(
        Contracts memory contracts,
        Staker[] memory stakersToBeWithdrawn,
        address[] memory arrDelegatedOperatorAddrForQueuedWithdrawals
    ) public { 

        /* getting the IDs of the operators */
        bytes32[] memory idsOfOperatorDelegatedTo = new bytes32[](stakersToBeWithdrawn.length);
        for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {
            vm.startBroadcast();
            idsOfOperatorDelegatedTo[i] = contracts
                                        .playgroundAVS
                                        .registryCoordinator
                                        .getOperator(arrDelegatedOperatorAddrForQueuedWithdrawals[i])
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
        vm.startBroadcast(stakersToBeWithdrawn[0].privateKey);
        contracts.playgroundAVS.registryCoordinator.stakeRegistry().updateStakes(
                                                                                arrDelegatedOperatorAddrForQueuedWithdrawals,
                                                                                idsOfOperatorDelegatedTo,
                                                                                prevElementArray
                                                                            );
        vm.stopBroadcast();

    }


    function completeQueuedWithdrawal(
        Contracts memory contracts,
        Staker memory stakerWithdrawing,
        uint32 withdrawalStartBlock,
        uint256 middlewareTimesIndex,
        address delegatedOperatorAddr,
        address[] memory strategyAddresses,
        uint256[] memory shares
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
                                            .numWithdrawalsQueued(stakerWithdrawing.addr))-1;
        vm.stopBroadcast();

        /* 
            creating queuedWithdrawal
        */
        IStrategyManager.QueuedWithdrawal memory queuedWithdrawal;

        // get strategies
        IStrategy[] memory strategies = new IStrategy[](strategyAddresses.length);
        for (uint i = 0; i < strategyAddresses.length; i++) {
            strategies[i] = IStrategy(strategyAddresses[i]);
        }

        queuedWithdrawal.strategies = strategies;
        queuedWithdrawal.shares = shares;
        queuedWithdrawal.depositor = stakerWithdrawing.addr;
        queuedWithdrawal.withdrawerAndNonce = withdrawerAndNonce;
        queuedWithdrawal.withdrawalStartBlock = withdrawalStartBlock;
        queuedWithdrawal.delegatedAddress = delegatedOperatorAddr;


        // get all the underlying tokens in the strategies
        IERC20[] memory tokens = new IERC20[](queuedWithdrawal.strategies.length);
        for (uint i = 0; i < queuedWithdrawal.strategies.length; i++) {
            tokens[i] = queuedWithdrawal.strategies[i].underlyingToken();
        }
        emit log_named_uint("queuedWithdrawal.strategies", queuedWithdrawal.strategies.length);
        emit log_named_uint("tokens", tokens.length);
        

        bool receiveAsTokens = true;

        emit log_named_bytes32("Computed root from reconstructed QueuedWithdrawal:",contracts.eigenlayer.strategyManager.calculateWithdrawalRoot(queuedWithdrawal));
        emit log_named_address("depositor", queuedWithdrawal.depositor);
        emit log_named_uint("nonce", queuedWithdrawal.withdrawerAndNonce.nonce);
        emit log_named_address("withdrawer", queuedWithdrawal.withdrawerAndNonce.withdrawer);
        emit log_named_uint("withdrawalStartBlock",  queuedWithdrawal.withdrawalStartBlock);
        emit log_named_address("delegatedAddress", queuedWithdrawal.delegatedAddress);
        emit log_named_address("strategies", address(queuedWithdrawal.strategies[0]));
        emit log_named_uint("shares",  queuedWithdrawal.shares[0]);



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

    function printStatusOfStakerForWithdrawals(
        string memory queuedWithdrawalOutputFile
    ) external {

        (uint32 withdrawalStartBlock, address[] memory arrDelegatedOperatorAddrForQueuedWithdrawals, bytes32[] memory withdrawalRoot) = parseBlockNumberAndOperatorDetailsFromQueuedWithdrawal(queuedWithdrawalOutputFile);


        for (uint256 i = 0; i < arrDelegatedOperatorAddrForQueuedWithdrawals.length; i++) {
            emit log_named_uint("PRINTING STATUS OF STAKER'S WITHDRAWAL", i);
            printStakerStatusForWithdrawalPurpose(
                    arrDelegatedOperatorAddrForQueuedWithdrawals[i], 
                    withdrawalRoot[i]
            );
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


    function printStakerStatusForWithdrawalPurpose(address operatorAddr, bytes32 withdrawalRoot) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        emit log_named_bytes32("withdrawalRoot",withdrawalRoot);
        bool withdrawalPending = StrategyManager(address(contracts.eigenlayer.strategyManager)).withdrawalRootPending(withdrawalRoot);
        emit log_named_string(
            "withdrawal is pending",
            convertBoolToString(withdrawalPending)
        );

        emit log_named_address("operator is:", operatorAddr);

        uint256 middlewareTimesLength = contracts.eigenlayer.slasher.middlewareTimesLength(
                                            operatorAddr
                                        );
        emit log_named_uint("middlewareTimesLength is:", middlewareTimesLength);

        uint32 middlewareTimesIndexStalestUpdateBlock = contracts.eigenlayer.slasher.getMiddlewareTimesIndexBlock(
                                            operatorAddr,
                                            uint32(middlewareTimesLength-1)
                                        );
        emit log_named_uint("PRINTING MIDDLEWARETIMESINDEXSTALESTUPDATEBLOCK FOR STAKER'S DELEGATED OPERATOR", middlewareTimesIndexStalestUpdateBlock);

        uint32 middlewareTimesIndexServeUntilBlock = contracts.eigenlayer.slasher.getMiddlewareTimesIndexServeUntilBlock(
                                            operatorAddr,
                                            uint32(middlewareTimesLength-1)
                                        );
        emit log_named_uint("PRINTING MIDDLEWARETIMESINDEXSERVEUNTILBLOCK IN RELATION TO STAKER", middlewareTimesIndexServeUntilBlock);

        

    }
}
