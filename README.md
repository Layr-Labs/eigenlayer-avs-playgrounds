# Eigenlayer AVS playgrounds

The purpose of this AVS playground is:
- learn how, as an AVS developer, can get your AVS contracts to interact with the interfaces that are provided by EigenLayer, 
- learn how you can do e2e testing for your AVS contracts,
- learn about registry contracts and understand how you can incorporate/use into your AVS contracts.

Before you delve further in AVS playground, it is essential that you are thinking deeply about the logic for your AVS contracts, namely, task submission and storage logic, slashing logic, registry contracts or you are implementing them. At either stage, you will find the AVS playground very useful. 

Another important point about AVS playground is that operators are not running any off-chain node software. For AVS playground, we just deployed registry contracts.


## Installation

```
git clone --recursive git@github.com:Layr-Labs/eigenlayer-avs-playgrounds.git
```

Make sure to clone with the `--recursive` flag to get the submodules (eigenlayer contracts and forge-test dependencies).

## Dependencies

You will need to [install foundry](https://book.getfoundry.sh/getting-started/installation). Also make sure to run `foundryup` to be on the latest version.

## Eigenlayer contracts

We have deployed a parallel set of contracts on goerli, with all functionality unpaused, for middleware teams to test with. The contract addresses can be found [here](./script/output/5/eigenlayer_deployment_output.json).
The easiest way to start integrating with these contracts is to fork goerli on a local `anvil` chain. You can install anvil using this [guide](https://book.getfoundry.sh/getting-started/installation):

```
anvil --fork-url https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161
```

If the above URL is not working, choose another one from https://chainlist.org/?testnets=true&search=goerli.

## Deploy the playgroundAVS contracts

In a separate terminal, run

```
export RPC_URL=http://localhost:8545
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
make deploy-avs
```

This deploys the playgroundAVS service manager contract (which you will need to modify to contain your own AVS' slashing logic) as well as a suite of registry contracts (which can most likely be used as-is for most AVSs).

## Makefile starting point

At any point run `make` to get info on the different possible commands.

<img src="./images/makefile.png" style="width: 100%"/>

## Operator and staker interactions



To register operators with EigenLayer, we use the following command: 
```
make register-operators-with-eigenlayer
```

To register operators with dummy registry contracts, we use the following command:
```
make register-operators-with-eigenlayer
```

For the staker to delegate to the operator, we use the following command:
```
make staker-delegate-to-operators:
```


At any point, to know the status of your operators and stakers, run the STATUS_PRINTERS functions

```
make print-operators-status
```
and
```
make print-stakers-status
```

The playground also supports stakers to queue withdrawal request for eithdrawing from EigenLayer and then complete their withdrawals.
For a lot more detail and explanation of each command in detail, look at the [runbook](./docs/runbook.md).

## Playbooks

After having deployed all contracts, you can interact with by running the different playbook scripts found in [script/playbooks](./script/playbooks/). These follow the structure outlined in the [AVS-guide](https://github.com/Layr-Labs/eigenlayer-contracts/blob/master/docs/AVS-Guide.md). Also have a look at the [AVS Smart Contracts Template Architecture](https://docs.google.com/document/d/1b_a5Xx5DugM_lWPOdv-vJ3wQnT20IwZ8e8RL6TtlgoM/edit?usp=sharing) doc to understand the registry contracts and how they interact with the service manager and eigenlayer contracts.
