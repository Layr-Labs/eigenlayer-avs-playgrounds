############################# HELP MESSAGE #############################
# Make sure the help command stays first, so that it's printed by default when `make` is called without arguments
.PHONY: help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
 
ifndef RPC_URL
$(error RPC_URL is not defined. Export it via `export RPC_URL=<url>`. eg: `export RPC_URL=http://localhost:8545`)
endif
ifndef PRIVATE_KEY
$(error PRIVATE_KEY is not defined. Export it via `export PRIVATE_KEY=<url>`. eg: `export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`)
endif

setup: ## Deploy avs, setup stakers, delegation to operators, register with eigenlayer and avs
	./setup.sh

# TODO(samlaf):
# 1. as an AVS, I want to get the % stake that has signed off on a message (from stake registry.. maybe wait for credible squaring)
# 2. integrate with some CLI wallet (clef? metamask snap? etc)
# TODO(soubhik): why is latestServeUntilBlock: 0 after registering

-----------------------------: ## 
___CONTRACTS_DEPLOYMENT___: ## 
## Deploy eigenlayer. Not needed when forking goerli
deploy-eigenlayer:
	forge script script/EigenLayerDeploy.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify --broadcast -v

deploy-avs: ## Deploy avs
	forge script script/PlaygroundAVSDeployer.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -v

-----------------------------: ## 
OPERATOR_INTERACTIONS: ## Below commands read from script/input/5/playground_avs_input.json


### Low level functions (run these if you want to understand what's going on):
fill-operator-keys-info:
	pushd crypto && go run .

register-operators-bn254-keys-with-avs-pubkey-compendium: fill-operator-keys-info 
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsBN254KeysWithAVSPubkeyCompendiumFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

opt-operators-into-slashing-by-avs:
	forge script script/playbooks/Operators.s.sol --sig "optOperatorsIntoSlashingByPlaygroundAVSFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

### High level functions:
register-operators-with-eigenlayer: ## 
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithEigenlayerFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

register-operators-with-avs: register-operators-bn254-keys-with-avs-pubkey-compendium opt-operators-into-slashing-by-avs ## registers bls keys with pubkey-compendium, opts into slashing by avs service-manager, and registers operators with avs registry
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithPlaygroundAVSFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input -v

deregister-operators-with-avs: ## 
	forge script script/playbooks/Operators.s.sol --sig "deregisterOperatorsWithPlaygroundAVSFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

-----------------------------: ## 
__STAKER_INTERACTIONS__: ## Below commands read from script/input/5/playground_avs_input.json

### Low level functions (run these if you want to understand what's going on):
staker-mint-tokens:
	forge script script/playbooks/Stakers.s.sol --sig "mintTokensToStakers(string memory avsConfigFile)" --rpc-url ${RPC_URL} -v --broadcast playground_avs_input 

staker-deposit-into-strategies:
	forge script script/playbooks/Stakers.s.sol --sig "depositIntoStrategies(string memory avsConfigFile)" --rpc-url ${RPC_URL} -v --broadcast playground_avs_input 

staker-delegate-to-operators:
	forge script script/playbooks/Stakers.s.sol --sig "delegateToOperators(string memory avsConfigFile)" --rpc-url ${RPC_URL} -v --broadcast playground_avs_input 

## Advance chain to permit completing the withdrawal (need to wait 10 blocks before completing a queued withdrawal, and localchain does not advance by itself)
advance-chain-by-100-blocks:
	forge script script/utils/Utils.sol --sig "advanceChainByNBlocks(uint256 n)" --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast 100

staker-queue-withdrawal:
	forge script script/playbooks/Stakers.s.sol --sig "queueWithdrawalFromEigenLayer(string memory avsConfigFile)" --rpc-url ${RPC_URL} -v --broadcast playground_avs_input

staker-notify-service-about-withdrawal:
	forge script script/playbooks/Stakers.s.sol --sig "notifyServiceAboutWithdrawal()" --rpc-url ${RPC_URL} -v --broadcast

staker-mint-deposit-delegate-to-operators: staker-mint-tokens staker-deposit-into-strategies staker-delegate-to-operators ## mint tokens, deposit into strategies, and delegate to operators

staker-queue-withdrawal-notify-avs: staker-queue-withdrawal staker-notify-service-about-withdrawal ## queue withdrawal on eigenlayer and notify avs to update the operator's delegated stake in registry

staker-complete-queued-withdrawal: advance-chain-by-100-blocks ## Complete queued withdrawals from the staker in EigenLayer
	forge script script/playbooks/Stakers.s.sol --sig "completeQueuedWithdrawalFromEigenLayer()" --rpc-url ${RPC_URL} -v --broadcast


-----------------------------: ## 
__WATCHER_INTERACTIONS__: ## 

freeze-operators: ## 
	forge script script/playbooks/Watchers.s.sol --sig "freezeOperatorsFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast playground_avs_input

-----------------------------: ## 
___STATUS_PRINTERS___: ## 

print-operators-status: ## Print status of all operators from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "printStatusOfOperatorsFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} playground_avs_input

print-stakers-status: ## Print status of all stakers from config file playground_avs_input.json
	forge script script/playbooks/Stakers.s.sol --sig "printStatusOfStakersFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} playground_avs_input

