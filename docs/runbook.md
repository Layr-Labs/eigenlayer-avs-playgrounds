# AVS Runbook - alpha-playground

This is meant as a programmatic follow-along guide to the [AVS Guide](https://github.com/Layr-Labs/eigenlayer-contracts/blob/master/docs/AVS-Guide.md) and the [AVS Smart Contract Architecture](https://docs.google.com/document/d/1EIs9CUaqcPCAYc5UGMRbu6y0BJP7FEY9eja_5lkg0aY/edit). The natgen generated [api docs](https://github.com/Layr-Labs/eigenlayer-contracts/tree/master/docs/docgen/core) for the core contracts will also be helpful, as will the contracts + actors architecture diagram. As a part of the alpha-playground program, our team has deployed a canonical set of contracts representing the EigeLayer protocol on the Goerli Testnet. Our recommendation is that AVS teams use these contracts to conduct any simulations they would like. Below we have added guidance on how to interact with these contracts in a local environment (forked from Goerli) using the Foundry toolkit.

<img src="../images/contracts-diagram.png" style="width: 80%"/>

## Makefile commands and their related contract interactions

All of the below commands read from [script/output/5/eigenlayer_deployment_output.json](../script/output/5/eigenlayer_deployment_output.json) and (after deploying the avs contracts) [script/output/5/playground_avs_deployment_output.json](../script/output/5/playground_avs_deployment_output.json). Note that the `5` refers to the chainid, goerli.

## Contracts Deployment

#### deploy-eigenlayer

The recommended way of interacting with this avs playground is to fork goerli on a local chain, and deploy the avs contracts on top of the eigenlayer contracts already deployed at the addresses in [script/output/5/eigenlayer_deployment_output.json](../script/output/5/eigenlayer_deployment_output.json). However, we still include this `deploy-eigenlayer` command for completeness. It can be used, for example, to deploy a fresh new set of eigenlayer contracts on an empty local chain instead of forking goerli. That would require setting the alphaMultisig to some EOA address whose private key is known, and using that to whitelist the [ERC20Mock.sol](../lib/eigenlayer-contracts/src/test/mocks/ERC20Mock.sol) contract in the strategy manager. The alphaMultisig on goerli is a proper 1/n gnosis safe, which teams needing to interact with the contracts (for eg., to unfreeze operators) should ask us to be added to.

#### deploy-avs

Deploying the avs contracts deploys the [PlaygroundAVSServiceManagerV1.sol](../src/core/PlaygroundAVSServiceManagerV1.sol) as well as the suite of [registry contracts](../lib/eigenlayer-contracts/src/contracts/middleware/), all of which are depicted in the image at the top of this runbook.

### Operator Interactions

#### register-operators-with-eigenlayer

Before doing anything else, an operator should first register with eigenlayer. This effectively enables stakers to delegate their assets to this operator. See [staker-delegate-to-operators](#staker-delegate-to-operators). Note that this does not register the operator with any AVS; it needs to register to each AVS' registry contract separately.

After running this command, you should be able to run [print-operators-status](#print-operators-status) and see the operator's status as opted-in (aka registered):

```
operator is opted in to eigenlayer: true
```

#### fill-operator-keys-info

This command runs a [golang binary](../crypto/main.go) whose sole purpose is to generate the BLS public keys and signatures required for the operator to [register with the pubkey compendium](#register-operators-bn254-keys-with-avs-pubkey-compendium). It reads the `ECDSAPrivateKey` fields and `BN254PrivateKey` fields from [script/input/5/playground_avs_input.json](../script/input/5/playground_avs_input.json) and generates a struct like the following for each operator:

```json
{
  "ECDSAPrivateKey": "0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97",
  "BN254PrivateKey": "0x1000",
  "BN254G1PublicKey": {
    "X": "13721099569423026850923337433982403324505725722819852841792898815211399675129",
    "Y": "16601117477696701067583705645824781346940621151880261081973621651314412226347"
  },
  "BN254G2PublicKey": {
    "X0": "21339205082113744844818902120687055060343938081750864912870488932652909233627",
    "Y0": "6261556775110212552820143758409413072248801726733731559359450028314604311538",
    "X1": "16011588866625460476897998592994630228752950831933448067206094363099214699792",
    "Y1": "11231279173142837985516440002115597978607256023911356951476335570928744152072"
  },
  "SchnorrSignatureOfECDSAAddress": "39975156338325939773073583190720765601090517081325092939360921481736180668",
  "SchnorrSignatureR": {
    "X": "18902908738025746854446008638853231217778244343386765018002287715666859394572",
    "Y": "11838852963291902375105792066112039527536049602301322232205681688835368183341"
  }
}
```

The `playground_avs_input.json` file is already filled with these information, but try removing all the fields, adding new private keys (both the ECDSA and BN254 ones are required!), and run this command to observe the file getting filled.

#### register-operators-bn254-keys-with-avs-pubkey-compendium

This will register the operator's BN254 public keys with the [BLSPublicKeyCompendium.sol](../lib/eigenlayer-contracts/src/contracts/middleware/BLSPublicKeyCompendium.sol) compendium, using the information generated from the [fill-operator-keys-info](#fill-operator-keys-info) command. This is a one-time registration, and is required before the operator can register with the playground AVS. Note also that this command will fail if the operator has not registered with eigenlayer first.

#### opt-operators-into-slashing-by-avs

#### register-operators-with-avs

#### deregister-operators-with-avs

### Staker Interactions

#### staker-mint-tokens-and-deposit-into-strategies

#### staker-delegate-to-operators

#### staker-queue-withdrawal

#### staker-notify-service-about-withdrawal

#### advanceChainBy100Blocks

#### staker-complete-queued-withdrawal

### Watcher Interactions

#### freeze-operators

### Status Printers

#### print-operators-status

This prints, for each operator:

```
PRINTING STATUS OF OPERATOR: 0
operator address: 0x23618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f
dummy token balance: 0
delegated shares in dummyTokenStrat: 0
operator pubkey hash in AVS pubkey compendium (0 if not registered): 0xfa513ae8a064e0fb50959c41249533404c2a7f8090ed79f0a44c85c9c418808c
operator is opted in to eigenlayer: true
operator is opted in to playgroundAVS (aka can be slashed): true
operator status in AVS registry: REGISTERED
    operatorId in AVS registry: 0xfa513ae8a064e0fb50959c41249533404c2a7f8090ed79f0a44c85c9c418808c
    operator fromTaskNumber in AVS registry: 0
operator is frozen: false
```
An operator initially starts with 0 delegated shares and all the fields set to false. Running through all the above commands sets each of these to true, one by one, until the operator is fully registered into everything contract needed and ready to serve actual AVS tasks.

#### print-stakers-status

This prints, for each staker:

```
PRINTING STATUS OF STAKER: 0
staker address: 0x70997970c51812dc3a010c7d01b50e0d17dc79c8
staker has delegated to some operator: false
staker has delegated to the operator:: 0x0000000000000000000000000000000000000000
```