// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/core/DelegationManager.sol";

import "@eigenlayer/contracts/core/StrategyManager.sol";
import "@eigenlayer/contracts/strategies/StrategyBase.sol";
import "@eigenlayer/contracts/core/Slasher.sol";

// Can't use the interface when we need access to state variables
import "@playground-avs/core/PlaygroundAVSServiceManagerV1.sol";

import "forge-std/Test.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract AddressBook is Script, DSTest {
    Vm cheats = Vm(HEVM_ADDRESS);

    struct Contracts {
        Eigenlayer eigenlayer;
        PlaygroundAVS playgroundAVS;
    }
    struct Eigenlayer {
        IDelegationManager delegationManager;
        IStrategyManager strategyManager;
        ISlasher slasher;
        StrategyBase dummyTokenStrat;
    }
    struct PlaygroundAVS {
        PlaygroundAVSServiceManagerV1 serviceManager;
        // TODO: add registry contracts
    }

    function getContracts(address playgroundAVSServiceManagerV1, address dummyTokenStrat) internal view returns (Contracts memory contracts) {
        contracts.playgroundAVS.serviceManager = PlaygroundAVSServiceManagerV1(playgroundAVSServiceManagerV1);
        contracts.eigenlayer.delegationManager = contracts.playgroundAVS.serviceManager.delegationManager();
        contracts.eigenlayer.strategyManager = contracts.playgroundAVS.serviceManager.strategyManager();
        contracts.eigenlayer.slasher = contracts.playgroundAVS.serviceManager.slasher();
        contracts.eigenlayer.dummyTokenStrat = StrategyBase(dummyTokenStrat);
    }
}
