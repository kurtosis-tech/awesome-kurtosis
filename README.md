<img src="./logo.png" width="1200">

Awesome Kurtosis [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)
===============================================================================

A curated list of [Kurtosis Packages](https://docs.kurtosis.com/concepts-reference/packages) written in [Starlark](https://docs.kurtosis.com/concepts-reference/starlark).

These packages provide a starting point for understanding how to setup, test, and manage different types of environments using the [Kurtosis CLI](https://docs.kurtosis.com/install).

You can run any of these examples without installing anything in [the Kurtosis Playground](https://gitpod.io/#/https://github.com/kurtosis-tech/playground-gitpod). Simply open the playground and run the following (swapping `redis-voting-app` with the subdirectory of the example you want):

```bash
kurtosis run github.com/kurtosis-tech/awesome-kurtosis/redis-voting-app
```

Contents
--------

- [Kurtosis Starlark Packages in the Web2 Space](#kurtosis-web2-examples)
- [Kurtosis Starlark Packages in the Web3 Space](#kurtosis-web3-examples)
- [Tests and other examples](#tests-and-other-examples)

### Kurtosis Web2 Examples

- [Auto-GPT Package](https://github.com/kurtosis-tech/autogpt-package) - A Kurtosis Starlark package that installs and starts AutoGPT locally with just 2 commands and with the memory backend of your choice. It's like AutoGPT got `brew install`. Built to simplify the install instructions of the popular open-source attempt to make GPT-4 fully autonomous: [Auto-GPT](https://github.com/Significant-Gravitas/Auto-GPT) by [Significant Gravitas](https://github.com/Significant-Gravitas).
- [Cassandra Package](https://github.com/kurtosis-tech/cassandra-package) - A Kurtosis Starlark Package that spins up an n node Cassandra cluster and verifies that the cluster that was spun up was healthy
- [Redis Package](https://github.com/kurtosis-tech/redis-package) - A Kurtosis Starlark Package that spins up a Redis instance
- [Etcd Package](https://github.com/kurtosis-tech/etcd-package) - A Kurtosis Starlark Package that spins up a Etcd instance - authored by [@laurentluce](https://github.com/laurentluce)
- [RabbitMq Package](https://github.com/kurtosis-tech/rabbitmq-package) - A Kurtosis Starlark Package that spins up a RabbitMQ instance - authored by [@laurentluce](https://github.com/laurentluce)
- [Datastore Army Package](https://github.com/kurtosis-tech/datastore-army-package) - A Kurtosis Starlark Package that spins up an n node Datastore server cluster

### Kurtosis Web3 Examples

- [Ethereum Package](https://github.com/kurtosis-tech/eth2-package) - A Kurtosis Starlark package that spins up a local Proof-of-Stake (PoS) Ethereum testnet, supporting supporting 9 different EL and CL clients including geth, lighthouse, lodestar, nimbus and erigon.
- [Avalanche Node Package](https://github.com/kurtosis-tech/avalanche-package) - A Kurtosis Starlark package that spins up a local, non-staking [Avalanche Go](https://github.com/ava-labs/avalanchego) node for local development and testing. This package can also be used to connect to other containerized services that make up your distributed system, like an instance of a wallet, indexer, explorer, or your dApp.
- [NEAR Package](https://github.com/kurtosis-tech/near-package) - A Kurtosis Starlark package that spins up a local NEAR testnet with a local RPC endpoint, a NEAR explorer, an indexer for the explorer, and a NEAR wallet.
- [Chainlink Node Package](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/chainlink-node#chainlink-node) - A Kurtosis Starlark package for instantiating a local Chainlink node for development and prototyping against Decentralized Oracle Networks (DONs). Includes the ability to optionally connect to a local multi-client Ethereum testnet, based off of the Ethereum Foundation's [Ethereum Package](https://github.com/kurtosis-tech/eth2-package). Inspiration comes from the original [Chainlink Node docs](https://docs.chain.link/chainlink-nodes/v1/running-a-chainlink-node).

### Tests and other examples

- [Cassandra Network Partition Test](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/cassandra-network-partition-test) - A test written in Kurtosis Starlark & Golang that verifies Cassandra's behavior under network failure using the [cassandra-package](https://github.com/kurtosis-tech/cassandra-package)
- [Ethereum Network Partition Test](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/ethereum-network-partition-test) - A test that verifies how the Ethereum network behaves under network partitioning. The test is written in both Golang and Starlark.
- [Quick Start](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/quickstart) - The example used in the [Quickstart guide](https://docs.kurtosis.com/quickstart) to get started with Kurtosis.
- [Simple NodeJS API](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/simple-api) - An example of how a Simple NodeJS based API can be setup to test using Kurtosis
- [Data Package](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/data-package) - An example package that contains a tar that you can import and use within the Quickstart and other packages
- [Redis Voting App](./redis-voting-app) - An example package highlighting composition in Kurtosis that uses the [redis-package](https://github.com/kurtosis-tech/redis-package) and [Azure Voting Front](https://github.com/Azure-Samples/azure-voting-app-redis/tree/master/azure-vote) to spin up a voting app backed by Redis.
