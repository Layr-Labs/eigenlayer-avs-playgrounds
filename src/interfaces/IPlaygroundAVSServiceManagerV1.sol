// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@eigenlayer/contracts/interfaces/IServiceManager.sol";
import "@eigenlayer/contracts/interfaces/IDelayedService.sol";
import "@eigenlayer/contracts/libraries/BN254.sol";
import "@eigenlayer/contracts/middleware/BLSSignatureChecker.sol";
import "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import "@eigenlayer/contracts/interfaces/IPaymentManager.sol";

interface IPlaygroundAVSServiceManagerV1 is IServiceManager, IDelayedService {

    // EVENTS

    event DummyEvent(DummyStruct);

    // STRUCTS

    struct DummyStruct {
        uint256 dummyUint;
    }

    // FUNCTIONS

    function dummyFunction() external;

}
