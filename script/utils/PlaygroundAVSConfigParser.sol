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

// Can't use the interface when we need access to state variables
import "@playground-avs/core/PlaygroundAVSServiceManagerV1.sol";

import "./Utils.sol";

import "forge-std/StdJson.sol";
import "forge-std/Script.sol";
import "forge-std/Test.sol";

contract PlaygroundAVSConfigParser is Script, DSTest, Utils {
    struct Staker {
        address addr;
        uint256 privateKey;
        uint256[] stakeAllocated;
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

    function parseConfigFileForStakersToBeWithdrawn(
        string memory avsConfigFile,
        Staker[] memory stakers
    ) public returns (Staker[] memory) {
        /* getting information on which stakers have to be withdrawn from the json file */
        // bytes memory indicesOfStakersTobeWithdrawnRaw = stdJson.parseRaw(
        //     avsConfigFile,
        //     ".indicesOfstakersToBeUnstaked"
        // );

        // uint256[] memory indicesOfStakersTobeWithdrawn = abi.decode(
        //     indicesOfStakersTobeWithdrawnRaw,
        //     (uint256[])
        // );

        // /* storing all the relevant info on these stakers to be withdrawn in an array */
        // Staker[] memory stakersToBeWithdrawn = new Staker[](indicesOfStakersTobeWithdrawn.length);
        // for(uint i = 0; i < indicesOfStakersTobeWithdrawn.length; i++) {
        //     stakersToBeWithdrawn[i] = stakers[indicesOfStakersTobeWithdrawn[i]];
        // }

        // @todo for not just hardcoded, need to get above working
        Staker[] memory stakersToBeWithdrawn = new Staker[](1);
        stakersToBeWithdrawn[0] = stakers[0];

        return stakersToBeWithdrawn;
    }

    function parseBlockNumberAndOperatorDetailsFromQueuedWithdrawal(
        string memory queuedWithdrawalOutputFile
    ) public returns (uint32, uint32) {
        string memory queuedWithdrawalOutput = vm.readFile("broadcast/Stakers.s.sol/5/queueWithdrawalFromEigenLayer-latest.json");
        uint32 blockNumber = uint32(stdJson.readUint(
            queuedWithdrawalOutput,
            ".receipts[0].blockNumber"
        ));

        bytes memory eventRaw =  stdJson.parseRaw(
            queuedWithdrawalOutput,
            ".receipts[0].blockNumber2"
        );
        emit log_bytes(eventRaw);

        uint32 blockno1;
        uint32 blockno2;
        (blockno1, blockno2)  = abi.decode(
            eventRaw,
            (uint32, uint32)
        );
        

        // bytes memory eventRaw =  stdJson.parseRaw(
        //     queuedWithdrawalOutput,
        //     ".receipts[0].logs[1].data"
        // );      

        // address depositor;
        // uint96 nonce;
        // address withdrawer;
        // address delegatedAddress;
        // bytes32 withdrawalRoot;
        // (depositor, nonce, withdrawer, delegatedAddress, withdrawalRoot)  = abi.decode(
        //     eventRaw,
        //     (address, uint96, address, address, bytes32)
        // );

        // emit log_address(delegatedAddress);
        // emit log_uint(nonce);
        return (blockNumber, blockno2);
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
