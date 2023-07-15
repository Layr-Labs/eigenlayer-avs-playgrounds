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


    function delegateToOperators(string memory avsConfigFile) external {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        /* parsing avsConfigFile for stakers */
        Staker[] memory stakers;
        // we are setting number of strategies to 1
        // TODO: change 1 to length of the dummyTokenStrat field in EigenLayer struct after array format is adopted
        stakers = parseStakersFromConfigFile(avsConfigFile, 1);

        // parsing avsConfigFile for operators
        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );

        // stakers delegating to the operators
        delegateToOperators(stakers, operators, contracts);
    }

    function allocateTokensToStakersAndDepositIntoStrategies(
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
        Operator[] memory operators = parseOperatorsFromConfigFile(
            avsConfigFile
        );

        depositIntoStrategies(stakers, operators, contracts);
    }

    function queueWithdrawalFromEigenLayer(
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
        stakersCurrentlyRestakedOnEigenLayer = parseStakersFromConfigFile(
            avsConfigFile,
            1
        );
        // emit log_address(stakersCurrentlyRestakedOnEigenLayer[0].addr);

        /* parsing avsConfigFile for stakers that are to be withdrawn */
        Staker[] memory stakersToBeWithdrawn;
        /* getting information on which stakers have to be withdrawn from the json file */
        stakersToBeWithdrawn = parseWithdrawalRequestFile(
            stakersCurrentlyRestakedOnEigenLayer
        );


        queueWithdrawalFromEigenLayer(contracts, stakersToBeWithdrawn);
    }



    // calling this function would update the record against all operators 
    function notifyServiceAboutWithdrawal() external {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        /* READ JSON DATA */
        QueuedWithdrawalOutput[] memory queuedWithdrawalOutputArr = readQueuedWithdrawalsDetails(0);
        
        // collect the addresses of the stakers that are withdrawing and their corresponding operators
        address[] memory addressesOfOperatorsForStakersWithdrawing = new address[](queuedWithdrawalOutputArr.length);
        address[] memory addressesOfStakersWithdrawing = new address[](queuedWithdrawalOutputArr.length);
        for (uint i = 0; i < queuedWithdrawalOutputArr.length; i++) {
            addressesOfStakersWithdrawing[i] = queuedWithdrawalOutputArr[i].stakerAddr;
            addressesOfOperatorsForStakersWithdrawing[i] = queuedWithdrawalOutputArr[i].operatorAddr;   
        }


        // collect the addresses of unique operators 
        address[] memory sanitizedAddressesOfOperatorsForStakersWithdrawing = new address[](addressesOfOperatorsForStakersWithdrawing.length);
        uint counter = 0;
        for (uint i = 0; i < addressesOfOperatorsForStakersWithdrawing.length; i++) {
            bool anyMatch = false;

            for (uint j = 0; j <= counter; j++) {
                if (sanitizedAddressesOfOperatorsForStakersWithdrawing[j] == addressesOfOperatorsForStakersWithdrawing[i]) {
                    anyMatch = true;
                    // TODO: use break?
                }
            }

            // new operator address being added
            if (anyMatch == false) {
                sanitizedAddressesOfOperatorsForStakersWithdrawing[counter] = addressesOfOperatorsForStakersWithdrawing[i];
                counter  = counter + 1;
            }
        }
        
        // get a clipped array, necessary for calling updateStake()
        address[] memory sanitizedAddressesOfOperatorsForStakersWithdrawingClipped = new address[](counter);
        for (uint i = 0; i < sanitizedAddressesOfOperatorsForStakersWithdrawingClipped.length; i++) {
            sanitizedAddressesOfOperatorsForStakersWithdrawingClipped[i] = sanitizedAddressesOfOperatorsForStakersWithdrawing[i];
        }


        // getting the IDs of the operators 
        bytes32[] memory idsOfOperatorDelegatedTo = new bytes32[](
            counter
        );
        for (uint i = 0; i < sanitizedAddressesOfOperatorsForStakersWithdrawingClipped.length; i++) {
            vm.startBroadcast();
            idsOfOperatorDelegatedTo[i] = contracts
                                            .playgroundAVS
                                            .registryCoordinator
                                            .getOperator(sanitizedAddressesOfOperatorsForStakersWithdrawingClipped[i])
                                            .operatorId;
            vm.stopBroadcast();
        }

       
        /* setting the element indices in the linked list _operatorToWhitelistedContractsByUpdate */
        uint256[] memory prevElementArray = new uint256[](
            counter
        );
        // @TODO change this to more general. For now, there is only one middleware
        for (uint i = 0; i < sanitizedAddressesOfOperatorsForStakersWithdrawingClipped.length; i++) {
            prevElementArray[i] = 0;
        }

        // call AVS's StakeRegistry for notifying the intention to withdraw
        vm.startBroadcast(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
        contracts
            .playgroundAVS
            .registryCoordinator
            .stakeRegistry()
            .updateStakes(
                sanitizedAddressesOfOperatorsForStakersWithdrawingClipped,
                idsOfOperatorDelegatedTo,
                prevElementArray
            );
        vm.stopBroadcast();


        // get middlewareTimeIndex for each of the stakers withdrawing
        uint256[] memory middlewareTimesIndicesOfStakersWithdrawing = new  uint256[](addressesOfOperatorsForStakersWithdrawing.length);
        for (uint i = 0; i < addressesOfOperatorsForStakersWithdrawing.length; i++) {
            middlewareTimesIndicesOfStakersWithdrawing[i] = contracts
                .eigenlayer
                .slasher
                .middlewareTimesLength(addressesOfOperatorsForStakersWithdrawing[i]) - 1;
        }

        // update the json file for queued withdrawals
        recordServiceNotification(addressesOfStakersWithdrawing, middlewareTimesIndicesOfStakersWithdrawing);
        
    }




    function completeQueuedWithdrawalFromEigenLayer(
        string memory avsConfigFile,
        string memory queuedWithdrawalOutputFile
    ) external {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );


        /* READ JSON DATA */
        QueuedWithdrawalOutput[] memory queuedWithdrawalsArr = readQueuedWithdrawalsDetails(0);
        bool receiveAsTokens = true;

        for (uint i = 0; i < queuedWithdrawalsArr.length; i++) {
            /* prepare the inputs for calling completeQueuedWithdrawals() */
        
            // prepare the input "queuedWithdrawals"
            IStrategyManager.QueuedWithdrawal memory completequeuedWithdrwalInput;
            
            IStrategy[] memory strategiesToBeWithdrawnFrom = new IStrategy[](queuedWithdrawalsArr[i].addressOfStrategiesToBeWithdrawnFrom.length);
            for (uint j = 0; j < queuedWithdrawalsArr[i].addressOfStrategiesToBeWithdrawnFrom.length; j++) {
                strategiesToBeWithdrawnFrom[j] = IStrategy(queuedWithdrawalsArr[i].addressOfStrategiesToBeWithdrawnFrom[j]);    
            }

            completequeuedWithdrwalInput.strategies = strategiesToBeWithdrawnFrom;
            completequeuedWithdrwalInput.shares = queuedWithdrawalsArr[i].sharesToBeWithdrawn;
            completequeuedWithdrwalInput.depositor = queuedWithdrawalsArr[i].stakerAddr;
            completequeuedWithdrwalInput.withdrawalStartBlock = queuedWithdrawalsArr[i].withdrawalStartBlock;
            completequeuedWithdrwalInput.delegatedAddress = queuedWithdrawalsArr[i].operatorAddr;
            completequeuedWithdrwalInput.withdrawerAndNonce.withdrawer = queuedWithdrawalsArr[i].stakerAddr;
            completequeuedWithdrwalInput.withdrawerAndNonce.nonce = queuedWithdrawalsArr[i].nonce;  

            emit log_named_bytes32(
                        "Computed root from reconstructed QueuedWithdrawal:",
                        contracts.eigenlayer.strategyManager.calculateWithdrawalRoot(
                            completequeuedWithdrwalInput
                        ));


            // prepare the input "middlewareTimesIndexes"
            uint256 middlewareTimesIndex; 
            middlewareTimesIndex = queuedWithdrawalsArr[i].middlewareTimesIndexForWithdrawal;
            

            // prepare the input "tokens"
            IERC20[] memory tokens = new IERC20[](completequeuedWithdrwalInput.strategies.length);
            for (uint j = 0; j < completequeuedWithdrwalInput.strategies.length; j++) {
                tokens[j] = completequeuedWithdrwalInput.strategies[j].underlyingToken();
            }


            // complete the queued withdrawal transaction
            vm.startBroadcast(queuedWithdrawalsArr[i].stakerPrivateKey);
            contracts.eigenlayer.strategyManager.completeQueuedWithdrawal(
                completequeuedWithdrwalInput,
                tokens,
                middlewareTimesIndex,
                receiveAsTokens
            );
            vm.stopBroadcast();

        }

        vm.writeFile("script/output/5/modified_queue_withdrawal_output.json", "");

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
            vm.startBroadcast(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            );
            _allocate(
                strategyAddresses[i],
                stakerAddresses,
                tokenAllocatedToStakers
            );
            vm.stopBroadcast();
        }
    }

    function depositIntoStrategies(
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
                    contracts
                        .eigenlayer
                        .dummyTokenStrat
                        .underlyingToken()
                        .approve(
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
            vm.stopBroadcast();
        }
    }

    function delegateToOperators(
        Staker[] memory stakers,
        Operator[] memory operators,
        Contracts memory contracts
    ) public {
        for (uint256 i = 0; i < stakers.length; i++) {
            if (
                contracts.eigenlayer.delegationManager.isDelegated(
                    stakers[i].addr
                )
            ) {
                // don't try to delegate if already delegated, otherwise it'll throw an error
                continue;
            }
            vm.startBroadcast(stakers[i].privateKey);
            // staker i is calling delegation manager to delegate its assets to some operator i
            contracts.eigenlayer.delegationManager.delegateTo(
                operators[i].ECDSAAddress
            );
            vm.stopBroadcast();
        }
    }

    function queueWithdrawalFromEigenLayer(
        Contracts memory contracts,
        Staker[] memory stakersToBeWithdrawn
    ) public {
        
        QueuedWithdrawalOutput[] memory queuedWithdrawalOutputArr = new QueuedWithdrawalOutput[](stakersToBeWithdrawn.length);
        
        for (uint i = 0; i < stakersToBeWithdrawn.length; i++) {

            /* storing the necessary data for completing queued withdrawal */
            queuedWithdrawalOutputArr[i].stakerAddr =  stakersToBeWithdrawn[i].addr;
            queuedWithdrawalOutputArr[i].stakerPrivateKey = stakersToBeWithdrawn[i].privateKey;
            
            
            vm.startBroadcast(stakersToBeWithdrawn[i].privateKey);
            
            queuedWithdrawalOutputArr[i].nonce = uint96(
                                        StrategyManager(address(contracts.eigenlayer.strategyManager))
                                            .numWithdrawalsQueued(stakersToBeWithdrawn[i].addr)
                                        );

            queuedWithdrawalOutputArr[i].operatorAddr = contracts
                                                        .eigenlayer.
                                                        delegationManager.
                                                        delegatedTo(stakersToBeWithdrawn[i].addr); 
             

            (IStrategy[] memory strategies, uint256[] memory shares) = contracts
                .eigenlayer
                .strategyManager
                .getDeposits(stakersToBeWithdrawn[i].addr);
            
            address[] memory strategyAddresses = new address[](strategies.length);
            for (uint j = 0; j < strategies.length; j++) {
                strategyAddresses[j] = address(strategies[j]);
            }
            
            queuedWithdrawalOutputArr[i].addressOfStrategiesToBeWithdrawnFrom = strategyAddresses;
            queuedWithdrawalOutputArr[i].sharesToBeWithdrawn = shares;
                                 
            

            /* queue withdrawal from EigenLayer */
            // currently withdrawal means every share is withdrawn from every strategy
            // TODO : make it flexible and have shares + strategy passed by the user
            uint256[] memory strategyIndexes = new uint256[](strategyAddresses.length);
            for (uint j = 0; j < strategyAddresses.length; j++) {
                strategyIndexes[j] = j;
            }
            bytes32 withdrawalRoot;



            withdrawalRoot = contracts
                .eigenlayer
                .strategyManager
                .queueWithdrawal(
                    strategyIndexes,
                    strategies,
                    shares,
                    // set the withdrawer to be staker itself
                    stakersToBeWithdrawn[i].addr,
                    true
                );

            vm.stopBroadcast();
            // TODO (Soubhik): this is just hacky way, find a proper resolutions
            queuedWithdrawalOutputArr[i].withdrawalStartBlock = uint32(block.number) + uint32(i) + 1;
            
        }
        parseAndUpdateQueuedWithdrawalsDetails(queuedWithdrawalOutputArr);

    }


    // STATUS PRINTER FUNCTIONS
    function printStatusOfStakersFromConfigFile(
        string memory avsConfigFile
    ) external {
        // TODO: change 1 to length of the dummyTokenStrat field in EigenLayer struct after array format is adopted
        Staker[] memory stakers = parseStakersFromConfigFile(avsConfigFile, 1);

        for (uint256 i = 0; i < stakers.length; i++) {
            emit log_named_uint("PRINTING STATUS OF STAKER", i);
            printStakerStatus(stakers[i].addr);
            emit log("--------------------------------------------------");
        }
    }

    function printStatusOfStakerForWithdrawals(
        string memory queuedWithdrawalOutputFile
    ) external {
        (
            uint32 withdrawalStartBlock,
            address[] memory arrDelegatedOperatorAddrForQueuedWithdrawals,
            bytes32[] memory withdrawalRoot
        ) = parseBlockNumberAndOperatorDetailsFromQueuedWithdrawal(
                queuedWithdrawalOutputFile
            );

        for (
            uint256 i = 0;
            i < arrDelegatedOperatorAddrForQueuedWithdrawals.length;
            i++
        ) {
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
        

        bool isDelegated = contracts.eigenlayer.delegationManager.isDelegated(
            stakerAddr
        );
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

    function printStakerStatusForWithdrawalPurpose(
        address operatorAddr,
        bytes32 withdrawalRoot
    ) public {
        Contracts memory contracts = parseContractsFromDeploymentOutputFiles(
            "eigenlayer_deployment_output",
            "playground_avs_deployment_output"
        );

        emit log_named_bytes32("withdrawalRoot", withdrawalRoot);
        bool withdrawalPending = StrategyManager(
            address(contracts.eigenlayer.strategyManager)
        ).withdrawalRootPending(withdrawalRoot);
        emit log_named_string(
            "withdrawal is pending",
            convertBoolToString(withdrawalPending)
        );

        emit log_named_address("operator is:", operatorAddr);

        uint256 middlewareTimesLength = contracts
            .eigenlayer
            .slasher
            .middlewareTimesLength(operatorAddr);
        emit log_named_uint("middlewareTimesLength is:", middlewareTimesLength);

        uint32 middlewareTimesIndexStalestUpdateBlock = contracts
            .eigenlayer
            .slasher
            .getMiddlewareTimesIndexBlock(
                operatorAddr,
                uint32(middlewareTimesLength - 1)
            );
        emit log_named_uint(
            "PRINTING MIDDLEWARETIMESINDEXSTALESTUPDATEBLOCK FOR STAKER'S DELEGATED OPERATOR",
            middlewareTimesIndexStalestUpdateBlock
        );

        uint32 middlewareTimesIndexServeUntilBlock = contracts
            .eigenlayer
            .slasher
            .getMiddlewareTimesIndexServeUntilBlock(
                operatorAddr,
                uint32(middlewareTimesLength - 1)
            );
        emit log_named_uint(
            "PRINTING MIDDLEWARETIMESINDEXSERVEUNTILBLOCK IN RELATION TO STAKER",
            middlewareTimesIndexServeUntilBlock
        );
    }
}
