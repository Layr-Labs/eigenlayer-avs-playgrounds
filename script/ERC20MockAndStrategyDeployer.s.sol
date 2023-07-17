// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.12;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import "@eigenlayer/contracts/interfaces/IETHPOSDeposit.sol";
import "@eigenlayer/contracts/interfaces/IBeaconChainOracle.sol";

import "@eigenlayer/contracts/core/StrategyManager.sol";
import "@eigenlayer/contracts/core/Slasher.sol";
import "@eigenlayer/contracts/core/DelegationManager.sol";

import "@eigenlayer/contracts/strategies/StrategyBaseTVLLimits.sol";

import "@eigenlayer/contracts/pods/EigenPod.sol";
import "@eigenlayer/contracts/pods/EigenPodManager.sol";
import "@eigenlayer/contracts/pods/DelayedWithdrawalRouter.sol";

import "@eigenlayer/contracts/permissions/PauserRegistry.sol";
import "@eigenlayer/contracts/middleware/BLSPublicKeyCompendium.sol";

import "@eigenlayer/test/mocks/EmptyContract.sol";
import "@eigenlayer/test/mocks/ETHDepositMock.sol";

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import "./utils/Utils.sol";

// # To load the variables in the .env file
// source .env

// # To deploy and verify our contract
// forge script script/ERC20MockAndStrategyDeployer.s.sol --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -v
contract ERC20MockAndStrategyDeployer is Script, Test, Utils {
    Vm cheats = Vm(HEVM_ADDRESS);

    // EigenLayer Contracts
    ProxyAdmin public eigenLayerProxyAdmin;
    PauserRegistry public eigenLayerPauserReg;
    StrategyManager public strategyManager;
    StrategyBase public ERC20MockStrategy;
    StrategyBase public ERC20MockStrategyImplementation;

    function run() external {
        // read and log the chainID
        uint256 chainId = block.chainid;
        emit log_named_uint("You are deploying on ChainID", chainId);

        // READ JSON CONFIG DATA
        string memory config_data = readOutput("eigenlayer_deployment_output");
        eigenLayerProxyAdmin = ProxyAdmin(
            stdJson.readAddress(config_data, ".addresses.eigenLayerProxyAdmin")
        );
        strategyManager = StrategyManager(
            stdJson.readAddress(config_data, ".addresses.strategyManager")
        );
        eigenLayerPauserReg = PauserRegistry(
            stdJson.readAddress(config_data, ".addresses.eigenLayerPauserReg")
        );

        // START RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.startBroadcast();

        IERC20 mockToken = new ERC20Mock();

        // deploy StrategyBaseTVLLimits contract implementation
        ERC20MockStrategyImplementation = new StrategyBase(strategyManager);

        ERC20MockStrategy = StrategyBase(
            address(
                new TransparentUpgradeableProxy(
                    address(ERC20MockStrategyImplementation),
                    address(eigenLayerProxyAdmin),
                    abi.encodeWithSelector(
                        StrategyBase.initialize.selector,
                        mockToken,
                        eigenLayerPauserReg
                    )
                )
            )
        );

        // STOP RECORDING TRANSACTIONS FOR DEPLOYMENT
        vm.stopBroadcast();

        emit log_named_address("ERC20Mock", address(mockToken));
        emit log_named_address("mockTokenStrategy", address(ERC20MockStrategy));
        emit log_named_address("mockTokenStrategyImplementation", address(ERC20MockStrategyImplementation));
    }
}
