// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/core/DelegationManager.sol";

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
        address addr;
        uint256 privateKey;
        BN254.G1Point blsPubKey;
    }
    struct Contracts {
        Eigenlayer eigenlayer;
        Tokens tokens;
        PlaygroundAVS playgroundAVS;
    }
    struct Eigenlayer {
        IDelegationManager delegationManager;
        IStrategyManager strategyManager;
        ISlasher slasher;
        StrategyBase dummyTokenStrat;
    }
    struct Tokens {
        IERC20 dummyToken;
    }
    struct PlaygroundAVS {
        PlaygroundAVSServiceManagerV1 serviceManager;
        IRegistryCoordinator registryCoordinator;
    }

    function parseStakersFromConfigFile(
        string memory input
    ) public returns (Staker[] memory, address[] memory) {
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
        // emit log_bytes(stakerTokenAmountsRaw);
        uint256[][] memory stakerTokenAmounts = abi.decode(
            stakerTokenAmountsRaw,
            (uint256[][])
        );
        // address[] memory strategies = stdJson.readAddressArray(avsConfig, ".strategies");
        uint numstrategies = stdJson
            .readAddressArray(avsConfig, ".strategies")
            .length;
        for (uint j = 0; j < stakers.length; j++) {
            uint256[] memory stake = new uint256[](numstrategies);
            for (uint i = 0; i < numstrategies; i++) {
                stake[i] = stakerTokenAmounts[i][j];
            }
            stakers[j].stakeAllocated = stake;
        }

        /* getting the strategy contracts */
        // StrategyBase[] memory strategyContracts = new StrategyBase[](numstrategies);
        address[] memory strategyContractsAddresses = stdJson.readAddressArray(
            avsConfig,
            ".strategies"
        );
        // for (uint i = 0; i < numstrategies; i++) {
        //     strategyContracts[i] = StrategyBase(strategyContractsAddresses[i]);
        // }

        return (stakers, strategyContractsAddresses);
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

        // parse contracts

        uint256[] memory operatorPrivateKeys = stdJson.readUintArray(
            avsConfig,
            ".operatorPrivateKeys"
        );
        Operator[] memory operators = getOperatorsFromPrivateKeys(
            operatorPrivateKeys
        );
        bytes memory operatorsBN254G1CoordinatesRaw = stdJson.parseRaw(
            avsConfig,
            ".operatorsBN254G1Coordinates"
        );
        uint256[][] memory operatorsBN254G1Coordinates = abi.decode(
            operatorsBN254G1CoordinatesRaw,
            (uint256[][])
        );
        for (uint256 i = 0; i < operators.length; i++) {
            operators[i].blsPubKey = BN254.G1Point(
                operatorsBN254G1Coordinates[i][0],
                operatorsBN254G1Coordinates[i][1]
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

    function getOperatorsFromPrivateKeys(
        uint256[] memory operatorPrivateKeys
    ) public pure returns (Operator[] memory operators) {
        operators = new Operator[](operatorPrivateKeys.length);
        for (uint i = 0; i < operators.length; i++) {
            operators[i].privateKey = operatorPrivateKeys[i];
            operators[i].addr = vm.addr(operators[i].privateKey);
        }
    }

    function getContractsFromServiceManager(
        address playgroundAVSServiceManagerV1,
        address dummyTokenStrat
    ) internal view returns (Contracts memory contracts) {
        contracts.playgroundAVS.serviceManager = PlaygroundAVSServiceManagerV1(
            playgroundAVSServiceManagerV1
        );
        contracts.playgroundAVS.registryCoordinator = contracts
            .playgroundAVS
            .serviceManager
            .registryCoordinator();
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
