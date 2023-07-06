# Eigenlayer AVS playgrounds

This repo contains a barebones AVS setup that can be used as a starting example for AVSs to test their integrations with eigenlayer and learn about our contracts' APIs.

## Installation
```
git clone --recursive git@github.com:Layr-Labs/eigenlayer-AVS-playgrounds.git
```
Make sure to clone with the `--recursive` flag to get the submodules (eigenlayer contracts and forge-test dependencies).

## Deploy Eigenlayer and the playgroundAVS contracts
Start anvil by running `anvil` in a terminal, and then in a separate terminal run
```
export RPC_URL=http://localhost:8545
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/DeployAndSetUpPlaygroundAVS.s.sol:DeployAndSetupPlaygroundAVS --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast -vvvv
```
This the Eigenlayer contracts along with the playgroundAVS service manager contract (which you will need to modify to contain your own AVS' slashing logic) as well as a suite of registry contracts (which can most likely be used as-is for most AVSs).

## Playbooks

After having deployed all contracts, you can interact with by running the different playbook scripts found in [script/playbooks](./script/playbooks/). These follow the structure outlined in the [AVS-guide](https://github.com/Layr-Labs/eigenlayer-contracts/blob/master/docs/AVS-Guide.md).