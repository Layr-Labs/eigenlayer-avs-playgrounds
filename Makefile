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

# TODO(missing functionality):
# 1. as an AVS, I want to get the % stake that has signed off on a message (from stake registry.. maybe wait for credible squaring)
# 2. integrate with some CLI wallet (clef? metamask snap? etc)
-----------------------------: ## 
___CONTRACTS_DEPLOYMENT___: ## 
deploy-eigenlayer: ## Deploy eigenlayer
	forge script script/EigenLayerDeploy.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify --broadcast -vvvv

deploy-avs: ## Deploy avs
	forge script script/PlaygroundAVSDeployer.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv

-----------------------------: ## 
OPERATOR_INTERACTIONS: ## Below commands read from script/input/5/playground_avs_input.json

fill-operator-keys-info: ## Reads operator ECDSA and BLS private keys and computes required public keys to register with BLSCompendium
	pushd crypto && go run .

register-operators-with-eigenlayer: ## 
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithEigenlayerFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

register-operators-bn254-keys-with-avs-pubkey-compendium: ## 
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsBN254KeysWithAVSPubkeyCompendiumFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input -vvvv

opt-operators-into-slashing-by-avs: ## 
	forge script script/playbooks/Operators.s.sol --sig "optOperatorsIntoSlashingByPlaygroundAVSFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input -vvvv

register-operators-with-avs: ## 
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithPlaygroundAVSFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input -vvvv

deregister-operators-with-avs: ## 
	forge script script/playbooks/Operators.s.sol --sig "deregisterOperatorsWithPlaygroundAVSFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

-----------------------------: ## 
__STAKER_INTERACTIONS__: ## 
setup-stakers-and-delegate-to-operator: ## Allocate tokens to stakers from config file playground_avs_input.json and do delegations of stakers to operators
	forge script script/playbooks/Stakers.s.sol --sig "allocateTokensToStakersAndDelegateToOperator(string memory avsConfigFile)" --rpc-url ${RPC_URL} -vvvv --broadcast playground_avs_input 

staker-queue-withdrawal: ## Queue withdrawals from the staker in EigenLayer
# TODO: queueWithdrawalFromEigenLayer-latest has been copied from the broadcast folder but this is just a hacky way
	forge script script/playbooks/Stakers.s.sol --sig "queueWithdrawalFromEigenLayer(string memory avsConfigFile, string memory queuedWithdrawalOutputFile)" --rpc-url ${RPC_URL} -vvvv --broadcast playground_avs_input queueWithdrawalFromEigenLayer-latest

-----------------------------: ## 
___STATUS_PRINTERS___: ## 

print-operators-status: ## Print status of all operators from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "printStatusOfOperatorsFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} playground_avs_input

print-stakers-status: ## Print status of all stakers from config file playground_avs_input.json
	forge script script/playbooks/Stakers.s.sol --sig "printStatusOfStakersFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} playground_avs_input
