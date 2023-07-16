// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/core/DelegationManager.sol";
import "@eigenlayer/contracts/interfaces/IBLSRegistryCoordinatorWithIndices.sol";

import "@eigenlayer/contracts/core/StrategyManager.sol";
import "@eigenlayer/contracts/strategies/StrategyBase.sol";
import "@eigenlayer/contracts/core/Slasher.sol";
import "@eigenlayer/contracts/libraries/BN254.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


// Can't use the interface when we need access to state variables
import "@playground-avs/core/PlaygroundAVSServiceManagerV1.sol";

import "./Utils.sol";

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract PlaygroundAVSConfigParser is Script, Test, Utils {
    // TODO: add the address of the operator to whom the staker has delegated here, easy for access
    struct Staker {
        address addr;
        uint256 privateKey;
        uint256[] stakeAllocated;
    }

    struct QueuedWithdrawalOutput {
        address stakerAddr;
        uint256 stakerPrivateKey;
        address operatorAddr;
        address[] addressOfStrategiesToBeWithdrawnFrom; 
        uint256[] sharesToBeWithdrawn;
        uint96 nonce;
        uint32 withdrawalStartBlock;
        uint256 isServiceNotifiedYet;
        uint256 middlewareTimesIndexForWithdrawal;
    }


    struct Operator {
        uint256 ECDSAPrivateKey;
        address ECDSAAddress;
        uint256 BN254PrivateKey;
        BN254.G1Point BN254G1PublicKey;
        BN254.G2Point BN254G2PublicKey;
        uint256 SchnorrSignatureOfECDSAAddress;
        BN254.G1Point SchnorrSignatureR;
    }
    struct Contracts {
        Eigenlayer eigenlayer;
        // TODO: change this to array format
        Tokens tokens;
        PlaygroundAVS playgroundAVS;
    }
    struct Eigenlayer {
        IDelegationManager delegationManager;
        IStrategyManager strategyManager;
        ISlasher slasher;
        // TODO: change this to array format
        StrategyBase dummyTokenStrat;
    }
    struct Tokens {
        IERC20 dummyToken;
    }
    struct PlaygroundAVS {
        PlaygroundAVSServiceManagerV1 serviceManager;
        IBLSRegistryCoordinatorWithIndices registryCoordinator;
    }

    /*
       This function is used for parsing information aboout all stakers. 
     */
    function parseStakersFromConfigFile(
        string memory input,
        uint numstrategies
    ) public returns (Staker[] memory) {
        string memory avsConfig = readInput(input);

        /* getting the staker private keys and address */
        Staker[] memory stakers;
        uint256[] memory stakerPrivateKeys = stdJson.readUintArray(
            avsConfig,
            ".stakerPrivateKeys"
        );
        stakers = getStakersFromPrivateKeysAndAddr(stakerPrivateKeys);

        /* getting the stake amount in different strategies */
        // stakerTokenAmount[i][j] is the amount of token i that staker j will receive
        bytes memory stakerTokenAmountsRaw = stdJson.parseRaw(
            avsConfig,
            ".stake"
        );

        uint256[][] memory stakerTokenAmounts = abi.decode(
            stakerTokenAmountsRaw,
            (uint256[][])
        );

        for (uint j = 0; j < stakers.length; j++) {
            uint256[] memory stake = new uint256[](numstrategies);
            for (uint i = 0; i < numstrategies; i++) {
                stake[i] = stakerTokenAmounts[i][j];
            }
            stakers[j].stakeAllocated = stake;
        }

        return stakers;
    }


    /*
       This function is used for parsing information about the type of withdrawal requests that needs to be made. 
     */    
    function parseWithdrawalRequestFile(
        Staker[] memory stakers
    ) public returns (Staker[] memory) {

        /* READ JSON DATA */
        string memory withdrawalRequestFile =  vm.readFile("script/input/5/withdrawal_request.json");
        uint numOfStakersToBeWithdrawn = stdJson.readUint(
                                        withdrawalRequestFile,
                                        ".numOfStakersToBeWithdrawn"
                                        );

        uint[] memory indicesOfStakersWithdrawing = new uint[](numOfStakersToBeWithdrawn);
        indicesOfStakersWithdrawing = stdJson.readUintArray(
                                            withdrawalRequestFile,
                                            ".indicesOfStakersToBeWithdrawn"
                                        );

        require(numOfStakersToBeWithdrawn == indicesOfStakersWithdrawing.length, "Withdrawal_request.json error: Please ensure numOfStakersToBeWithdrawn is same as the length of indicesOfStakersToBeWithdrawn"); 
        
        // getting actual details on the stakers who have put in withdrawal requests
        Staker[] memory stakersWithdrawing = new Staker[](indicesOfStakersWithdrawing.length);
        for (uint i = 0; i < indicesOfStakersWithdrawing.length; i++) {
            stakersWithdrawing[i] = stakers[indicesOfStakersWithdrawing[i]];
        }

        return stakersWithdrawing;
    }


    // TODO (Soubhik): define shift properly here
    function readQueuedWithdrawalsDetails(
        uint shift
    ) public returns (QueuedWithdrawalOutput[] memory) {

        /* READ JSON DATA */
        string memory queuedWithdrawalOutputFile = vm.readFile("script/output/5/modified_queue_withdrawal_output.json");
        uint numOldQueuedWithdrawals;

        if (bytes(queuedWithdrawalOutputFile).length == 0) {
            // if it is an empty file
            numOldQueuedWithdrawals = 0;
        } else {
            // if it is not an empty file
            numOldQueuedWithdrawals = uint(stdJson.readUint(
                                            queuedWithdrawalOutputFile,
                                            ".numQueuedWithdrawals.numQueuedWithdrawals"
                                        ));
        }
        
        
        QueuedWithdrawalOutput[] memory oldQueuedWithdrawalOutputArr = new QueuedWithdrawalOutput[](numOldQueuedWithdrawals + shift);
        
        if (bytes(queuedWithdrawalOutputFile).length != 0) {
            // if it is not an empty file
            string[] memory oldQueuedWithdrawalTag = new string[](numOldQueuedWithdrawals);

            // reading old queued withdrawals 
            for (uint i = 0; i < numOldQueuedWithdrawals; i++){
                oldQueuedWithdrawalTag[i] = string.concat("queuedWithdrawal", Strings.toString(i));

                oldQueuedWithdrawalOutputArr[i].stakerAddr = stdJson.readAddress(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".stakerAddr")
                                );

                oldQueuedWithdrawalOutputArr[i].stakerPrivateKey = stdJson.readUint(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".stakerPrivateKey")
                                );

                oldQueuedWithdrawalOutputArr[i].operatorAddr = stdJson.readAddress(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".operatorAddr")
                                );
                
                oldQueuedWithdrawalOutputArr[i].addressOfStrategiesToBeWithdrawnFrom = stdJson.readAddressArray(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".addressOfStrategiesToBeWithdrawnFrom")
                                );


                oldQueuedWithdrawalOutputArr[i].sharesToBeWithdrawn = stdJson.readUintArray(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".sharesToBeWithdrawn")
                                );

                oldQueuedWithdrawalOutputArr[i].nonce = uint96(stdJson.readUint(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".nonce")
                                ));

                oldQueuedWithdrawalOutputArr[i].withdrawalStartBlock = uint32(stdJson.readUint(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".withdrawalStartBlock")
                                ));

                oldQueuedWithdrawalOutputArr[i].isServiceNotifiedYet = stdJson.readUint(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".isServiceNotifiedYet")
                                );

                oldQueuedWithdrawalOutputArr[i].middlewareTimesIndexForWithdrawal = stdJson.readUint(
                                    queuedWithdrawalOutputFile,
                                    string.concat(".",oldQueuedWithdrawalTag[i],".middlewareTimesIndexForWithdrawal")
                                );
            }
        }
        return oldQueuedWithdrawalOutputArr;

    }

    function writeQueuedWithdrawalsDetails(
        uint totLength,
        QueuedWithdrawalOutput[] memory queuedWithdrawalOutputArr,
        string memory filename
    ) public returns (QueuedWithdrawalOutput[] memory) {

        string memory parentObject = "parent object";
        string memory finalJson;
        string[] memory queuedWithdrawaloutputStringify = new string[](totLength);
        string[] memory queuedWithdrawalTag = new string[](totLength);

        uint numQueuedWithdrawals = totLength;
        string memory numQueuedWithdrawalsTag = "numQueuedWithdrawals";
        string memory numQueuedWithdrawalsStringify = vm.serializeUint(
                    numQueuedWithdrawalsTag,
                    "numQueuedWithdrawals",
                    numQueuedWithdrawals
        );

        
        for (uint i = 0; i < totLength; i++) {
            queuedWithdrawalTag[i] = string.concat("queuedWithdrawal", Strings.toString(i));
            
            vm.serializeAddress(
                    queuedWithdrawalTag[i],
                    "stakerAddr",
                    queuedWithdrawalOutputArr[i].stakerAddr
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "stakerPrivateKey",
                    queuedWithdrawalOutputArr[i].stakerPrivateKey
                );

            vm.serializeAddress(
                    queuedWithdrawalTag[i],
                    "operatorAddr",
                    queuedWithdrawalOutputArr[i].operatorAddr
                );

            vm.serializeAddress(
                    queuedWithdrawalTag[i],
                    "addressOfStrategiesToBeWithdrawnFrom",
                    queuedWithdrawalOutputArr[i].addressOfStrategiesToBeWithdrawnFrom
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "sharesToBeWithdrawn",
                    queuedWithdrawalOutputArr[i].sharesToBeWithdrawn
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "isServiceNotifiedYet",
                    queuedWithdrawalOutputArr[i].isServiceNotifiedYet
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "middlewareTimesIndexForWithdrawal",
                    queuedWithdrawalOutputArr[i].middlewareTimesIndexForWithdrawal
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "nonce",
                    queuedWithdrawalOutputArr[i].nonce
                );
            
            queuedWithdrawaloutputStringify[i] = vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "withdrawalStartBlock",
                    queuedWithdrawalOutputArr[i].withdrawalStartBlock
                );

        }


        vm.serializeString(
            parentObject,
            numQueuedWithdrawalsTag,
            numQueuedWithdrawalsStringify
        );

        for (uint i = 0; i < queuedWithdrawaloutputStringify.length; i++) {
            
            if (i !=  queuedWithdrawaloutputStringify.length - 1) {
                vm.serializeString(
                    parentObject,
                    queuedWithdrawalTag[i],
                    queuedWithdrawaloutputStringify[i]
                );
            } else {
                finalJson = vm.serializeString(
                    parentObject,
                    queuedWithdrawalTag[i],
                    queuedWithdrawaloutputStringify[i]
                );
            }

        }

        writeOutput(finalJson, filename);

    }


    function parseAndUpdateQueuedWithdrawalsDetails (
        QueuedWithdrawalOutput[] memory newQueuedWithdrawalOutputArr
    ) public {

        // /* READ JSON DATA */
        string memory queuedWithdrawalOutputFile = vm.readFile("script/output/5/modified_queue_withdrawal_output.json");
        uint numOldQueuedWithdrawals;

        if (bytes(queuedWithdrawalOutputFile).length == 0) {
            // if it is an empty file
            numOldQueuedWithdrawals = 0;
        } else {
            // if it is not an empty file
            numOldQueuedWithdrawals = uint(stdJson.readUint(
                                            queuedWithdrawalOutputFile,
                                            ".numQueuedWithdrawals.numQueuedWithdrawals"
                                        ));
        }
        
        emit log_string("pre read");
        QueuedWithdrawalOutput[] memory oldQueuedWithdrawalOutputArr = new QueuedWithdrawalOutput[](numOldQueuedWithdrawals + newQueuedWithdrawalOutputArr.length);
        oldQueuedWithdrawalOutputArr = readQueuedWithdrawalsDetails(newQueuedWithdrawalOutputArr.length);    
        emit log_string("post read");

        /* WRITE JSON DATA */
        // copying all data
        uint validWithdrawalCounter = 0;
        for(uint i = 0; i < newQueuedWithdrawalOutputArr.length; i++) {
            if (newQueuedWithdrawalOutputArr[i].operatorAddr != address(0)) {
                oldQueuedWithdrawalOutputArr[validWithdrawalCounter + numOldQueuedWithdrawals] = newQueuedWithdrawalOutputArr[i];
                validWithdrawalCounter = validWithdrawalCounter + 1;
            }
        }
        validWithdrawalCounter = validWithdrawalCounter + numOldQueuedWithdrawals;

        string memory parentObject = "parent object";
        string memory finalJson;
        string[] memory queuedWithdrawaloutputStringify = new string[](validWithdrawalCounter);
        string[] memory queuedWithdrawalTag = new string[](validWithdrawalCounter);

        uint numQueuedWithdrawals = validWithdrawalCounter;
        string memory numQueuedWithdrawalsTag = "numQueuedWithdrawals";
        string memory numQueuedWithdrawalsStringify = vm.serializeUint(
                    numQueuedWithdrawalsTag,
                    "numQueuedWithdrawals",
                    numQueuedWithdrawals
        );

        
        for (uint i = 0; i < validWithdrawalCounter; i++) {
            queuedWithdrawalTag[i] = string.concat("queuedWithdrawal", Strings.toString(i));
            
            vm.serializeAddress(
                    queuedWithdrawalTag[i],
                    "stakerAddr",
                    oldQueuedWithdrawalOutputArr[i].stakerAddr
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "stakerPrivateKey",
                    oldQueuedWithdrawalOutputArr[i].stakerPrivateKey
                );

            vm.serializeAddress(
                    queuedWithdrawalTag[i],
                    "operatorAddr",
                    oldQueuedWithdrawalOutputArr[i].operatorAddr
                );

            vm.serializeAddress(
                    queuedWithdrawalTag[i],
                    "addressOfStrategiesToBeWithdrawnFrom",
                    oldQueuedWithdrawalOutputArr[i].addressOfStrategiesToBeWithdrawnFrom
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "sharesToBeWithdrawn",
                    oldQueuedWithdrawalOutputArr[i].sharesToBeWithdrawn
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "isServiceNotifiedYet",
                    oldQueuedWithdrawalOutputArr[i].isServiceNotifiedYet
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "middlewareTimesIndexForWithdrawal",
                    oldQueuedWithdrawalOutputArr[i].middlewareTimesIndexForWithdrawal
                );

            vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "nonce",
                    oldQueuedWithdrawalOutputArr[i].nonce
                );
            
            queuedWithdrawaloutputStringify[i] = vm.serializeUint(
                    queuedWithdrawalTag[i],
                    "withdrawalStartBlock",
                    oldQueuedWithdrawalOutputArr[i].withdrawalStartBlock
                );

        }

        vm.serializeString(
            parentObject,
            numQueuedWithdrawalsTag,
            numQueuedWithdrawalsStringify
        );

        for (uint i = 0; i < queuedWithdrawaloutputStringify.length; i++) {
            
            if (i !=  queuedWithdrawaloutputStringify.length - 1) {
                vm.serializeString(
                    parentObject,
                    queuedWithdrawalTag[i],
                    queuedWithdrawaloutputStringify[i]
                );
            } else {
                finalJson = vm.serializeString(
                    parentObject,
                    queuedWithdrawalTag[i],
                    queuedWithdrawaloutputStringify[i]
                );
            }

        }

        writeOutput(finalJson, "modified_queue_withdrawal_output");    
    }

    /* 
        NOTE: Currently this can support only one AVS and withdrawals where stakers 
        withdraws completely from all strategies. Next version, modify the following 
        function to support this.
    */
    function recordServiceNotification (
        address[] memory addrOfStakersWithdrawing,
        uint256[] memory middlewareTimesIndices
    ) public {

        /* READ JSON DATA */
        string memory queuedWithdrawalOutputFile = vm.readFile("script/output/5/modified_queue_withdrawal_output.json");
        uint numOldQueuedWithdrawals;

        if (bytes(queuedWithdrawalOutputFile).length == 0) {
            // if it is an empty file
            numOldQueuedWithdrawals = 0;
        } else {
            // if it is not an empty file
            numOldQueuedWithdrawals = uint(stdJson.readUint(
                                            queuedWithdrawalOutputFile,
                                            ".numQueuedWithdrawals.numQueuedWithdrawals"
                                        ));
        }

        QueuedWithdrawalOutput[] memory oldQueuedWithdrawalOutputArr = new QueuedWithdrawalOutput[](numOldQueuedWithdrawals);
        oldQueuedWithdrawalOutputArr = readQueuedWithdrawalsDetails(0);  


        for (uint i = 0; i < addrOfStakersWithdrawing.length; i++) {
            for (uint j = 0; j < oldQueuedWithdrawalOutputArr.length; j++) {
                if (oldQueuedWithdrawalOutputArr[j].stakerAddr == addrOfStakersWithdrawing[i]) {
                    oldQueuedWithdrawalOutputArr[j].isServiceNotifiedYet = 1;
                    oldQueuedWithdrawalOutputArr[j].middlewareTimesIndexForWithdrawal = middlewareTimesIndices[i];
                }
            }
        }

        writeQueuedWithdrawalsDetails(oldQueuedWithdrawalOutputArr.length, 
                                    oldQueuedWithdrawalOutputArr, 
                                    "modified_queue_withdrawal_output"
                                    );

    }
 


    function parseContractsFromDeploymentOutputFiles(
        string memory eigenlayerDeploymentOutputFile,
        string memory avsDeploymentOutputFile
    ) public returns (Contracts memory) {
        string memory eigenlayerDeploymentOutput = readOutput(
            eigenlayerDeploymentOutputFile
        );
        string memory avsDeploymentOutput = readOutput(avsDeploymentOutputFile);

        address playgroundAVSStrategyManagerV1 = stdJson.readAddress(
            avsDeploymentOutput,
            ".addresses.playgroundAVSServiceManager"
        );
        address tokenStrat = stdJson.readAddress(
            eigenlayerDeploymentOutput,
            ".addresses.baseStrategy"
        );
        Contracts memory contracts = getContractsFromServiceManager(
            playgroundAVSStrategyManagerV1,
            tokenStrat
        );

        return contracts;
    }

    function parseOperatorsFromConfigFile(
        string memory configFileName
    ) public returns (Operator[] memory) {
        string memory avsConfig = readInput(configFileName);

        Operator[] memory operators = new Operator[](2);
        for (uint256 i = 0; i < 2; i++) {
            // parsing structs via rawjson (https://book.getfoundry.sh/cheatcodes/parse-json?highlight=stdjso#decoding-json-objects-into-solidity-structs)
            // is a real pain in the @$$, so we opted against using it
            string memory baseSelector = string.concat(
                ".operators[",
                vm.toString(uint256(i)),
                "]"
            );
            operators[i].ECDSAPrivateKey = stdJson.readUint(
                avsConfig,
                string.concat(baseSelector, ".ECDSAPrivateKey")
            );
            operators[i].ECDSAAddress = vm.addr(operators[i].ECDSAPrivateKey);
            operators[i].BN254PrivateKey = stdJson.readUint(
                avsConfig,
                string.concat(baseSelector, ".BN254PrivateKey")
            );
            operators[i].BN254G1PublicKey = BN254.G1Point(
                stdJson.readUint(
                    avsConfig,
                    string.concat(baseSelector, ".BN254G1PublicKey.X")
                ),
                stdJson.readUint(
                    avsConfig,
                    string.concat(baseSelector, ".BN254G1PublicKey.Y")
                )
            );
            // Note the reverse ordering! This is important. See comments in BN254 for more info
            operators[i].BN254G2PublicKey = BN254.G2Point(
                [
                    stdJson.readUint(
                        avsConfig,
                        string.concat(baseSelector, ".BN254G2PublicKey.X1")
                    ),
                    stdJson.readUint(
                        avsConfig,
                        string.concat(baseSelector, ".BN254G2PublicKey.X0")
                    )
                ],
                [
                    stdJson.readUint(
                        avsConfig,
                        string.concat(baseSelector, ".BN254G2PublicKey.Y1")
                    ),
                    stdJson.readUint(
                        avsConfig,
                        string.concat(baseSelector, ".BN254G2PublicKey.Y0")
                    )
                ]
            );
            operators[i].SchnorrSignatureR = BN254.G1Point(
                stdJson.readUint(
                    avsConfig,
                    string.concat(baseSelector, ".SchnorrSignatureR.X")
                ),
                stdJson.readUint(
                    avsConfig,
                    string.concat(baseSelector, ".SchnorrSignatureR.Y")
                )
            );
            operators[i].SchnorrSignatureOfECDSAAddress = stdJson.readUint(
                avsConfig,
                string.concat(baseSelector, ".SchnorrSignatureOfECDSAAddress")
            );
        }

        return operators;
    }

    function getStakersFromPrivateKeysAndAddr(
        uint256[] memory stakerPrivateKeys
    ) public pure returns (Staker[] memory stakers) {
        stakers = new Staker[](stakerPrivateKeys.length);
        for (uint i = 0; i < stakers.length; i++) {
            stakers[i].privateKey = stakerPrivateKeys[i];
            stakers[i].addr = vm.addr(stakerPrivateKeys[i]);
        }
    }

    function getContractsFromServiceManager(
        address playgroundAVSServiceManagerV1,
        address dummyTokenStrat
    ) internal view returns (Contracts memory contracts) {
        contracts.playgroundAVS.serviceManager = PlaygroundAVSServiceManagerV1(
            playgroundAVSServiceManagerV1
        );
        contracts.playgroundAVS.registryCoordinator = IBLSRegistryCoordinatorWithIndices(address(contracts
            .playgroundAVS
            .serviceManager
            .registryCoordinator()));
        contracts.eigenlayer.delegationManager = contracts
            .playgroundAVS
            .serviceManager
            .delegationManager();
        contracts.eigenlayer.strategyManager = contracts
            .playgroundAVS
            .serviceManager
            .strategyManager();
        contracts.eigenlayer.slasher = contracts
            .playgroundAVS
            .serviceManager
            .slasher();
        contracts.eigenlayer.dummyTokenStrat = StrategyBase(dummyTokenStrat);
        contracts.tokens.dummyToken = contracts
            .eigenlayer
            .dummyTokenStrat
            .underlyingToken();
    }
}
