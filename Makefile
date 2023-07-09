############################# HELP MESSAGE #############################
# Make sure the help command stays first, so that it's printed by default when `make` is called without arguments
.PHONY: help
help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
 
___CONTRACTS_DEPLOYMENT___: ## 
deploy-eigenlayer: ## Deploy eigenlayer
	forge script script/EigenLayerDeploy.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv

deploy-avs: ## Deploy avs
	forge script script/PlaygroundAVSDeployer.s.sol --rpc-url ${RPC_URL}  --private-key ${PRIVATE_KEY} --broadcast -vvvv

___OPERATOR_INTERACTIONS___: ## 

register-operators-with-eigenlayer-and-avs: ## Register operators from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "registerOperatorsWithEigenlayerAndAvsFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} playground_avs_input

___STATUS_PRINTERS___: ## 

print-operators-status: ## Print status of all operators from config file playground_avs_input.json
	forge script script/playbooks/Operators.s.sol --sig "printStatusOfOperatorsFromConfigFile(string memory avsConfigFile)" --rpc-url ${RPC_URL} playground_avs_input