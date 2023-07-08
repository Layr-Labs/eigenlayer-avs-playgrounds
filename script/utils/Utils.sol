// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@eigenlayer/contracts/interfaces/IRegistryCoordinator.sol";
import "@eigenlayer/contracts/strategies/StrategyBase.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract Utils {
    function _allocate(
        IERC20 token,
        address[] memory tos,
        uint256[] memory amounts
    ) internal {
        for (uint256 i = 0; i < tos.length; i++) {
            if (token == IERC20(address(0))) {
                payable(tos[i]).transfer(amounts[i]);
            } else {
                token.transfer(tos[i], amounts[i]);
            }
        }
    }
    
    function _allocateNew(
        address strategyAddress,
        address[] memory tos,
        uint256[] memory amounts
    ) internal {
        for (uint256 i = 0; i < tos.length; i++) {
            IERC20 underlyingToken = StrategyBase(strategyAddress).underlyingToken();
            underlyingToken.transfer(tos[i], amounts[i]);
        }
    }

    function convertBoolToString(
        bool input
    ) public pure returns (string memory) {
        if (input) {
            return "true";
        } else {
            return "false";
        }
    }

    function convertOperatorStatusToString(
        IRegistryCoordinator.OperatorStatus operatorStatus
    ) public pure returns (string memory) {
        if (
            operatorStatus ==
            IRegistryCoordinator.OperatorStatus.NEVER_REGISTERED
        ) {
            return "NEVER_REGISTERED";
        } else if (
            operatorStatus == IRegistryCoordinator.OperatorStatus.REGISTERED
        ) {
            return "REGISTERED";
        } else if (
            operatorStatus == IRegistryCoordinator.OperatorStatus.DEREGISTERED
        ) {
            return "DEREGISTERED";
        } else {
            return "UNKNOWN";
        }
    }
}
