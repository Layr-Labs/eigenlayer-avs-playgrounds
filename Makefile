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

___CONTRACTS_DEPLOYMENT___: ## 
deploy-eigenlayer: ## Deploy eigenlayer
	forge script script/EigenLayerDeploy.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --etherscan-api-key ${ETHERSCAN_API_KEY} --verify --broadcast -vvvv

deploy-avs: ## Deploy avs
	forge script script/PlaygroundAVSDeployer.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv

___OPERATOR_INTERACTIONS___: ## 

register-operators-with-eigenlayer: ## Register operators with eigenlayer from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithEigenlayerFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

register-operators-with-avs: ## Register operators with playground-avs from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithPlaygroundAVSFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

register-operators-with-eigenlayer-and-avs: ## Register operators from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithEigenlayerAndAvsFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} --broadcast playground_avs_input

___STATUS_PRINTERS___: ## 

print-operators-status: ## Print status of all operators from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "printStatusOfOperatorsFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} playground_avs_input



__STAKER_INTERACTIONS__: ##
setup-stakers-and-delegate-to-operator: ## Allocate tokens to stakers from config file playground_avs_input.json and do delegations of stakers to operators
	forge script script/playbooks/Stakers.s.sol --sig "allocateTokensToStakersAndDelegateToOperator(string memory avsConfigFile)" --rpc-url ${RPC_URL} -vvvv --broadcast playground_avs_input