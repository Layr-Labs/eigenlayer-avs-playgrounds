// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// import "forge-std/Script.sol";
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

    function convertBoolToString(
        bool input
    ) public pure returns (string memory) {
        if (input) {
            return "true";
        } else {
            return "false";
        }
    }
}
