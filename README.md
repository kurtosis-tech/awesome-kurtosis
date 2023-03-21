# Awesome Kurtosis [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

<img src="./logo.png" width="500">

> A curated list of [Kurtosis Packages ](https://docs.kurtosis.com/reference/packages) written in [Starlark](https://docs.kurtosis.com/explanations/starlark)

These example [Kurtosis packages](https://docs.kurtosis.com/reference/packages) provide a starting point for understanding how to setup, test, and manage different types of environments using [Starlark](https://docs.kurtosis.com/explanations/starlark) and the [Kurtosis CLI](https://docs.kurtosis.com/install).

> **Note**
> Feel free to use Kurtosis however you want, as long as you’re not directly re-selling “Kurtosis-as-a-service” to customers.

## Contents

- [Kurtosis Starlark Packages in the Web2 Space](#kurtosis-starlark-web2-examples)
- [Kurtosis Starlark Packages in the Web3 Space](#kurtosis-starlark-web3-examples)
- [Tests and other examples](#tests-and-other-examples)

## Kurtosis Starlark Web2 Examples

- [Cassandra Package](https://github.com/kurtosis-tech/cassandra-package) - A Kurtosis Starlark Package that spins up an n node Cassandra cluster and verifies that the cluster that was spun up was healthy
- [Datastore Army Package](https://github.com/kurtosis-tech/datastore-army-package) - A Kurtosis Starlark Package that spins up an n node Datastore server cluster
- [Redis Package](https://github.com/kurtosis-tech/redis-package) - A Kurtosis Starlark Package that spins up a Redis instance

## Kurtosis Starlark Web3 Examples

- [Ethereum Package](https://github.com/kurtosis-tech/eth2-package) - A Kurtosis Starlark Package that spins up a local Proof-of-Stake (PoS) Ethereum testnet, supporting supporting 9 different EL and CL clients including geth, lighthouse, lodestar, nimbus and erigon.
- [NEAR Package](https://github.com/kurtosis-tech/near-package) - A Kurtosis Starlark package that spins up a local NEAR testnet with a local RPC endpoint, a NEAR explorer, an indexer for the explorer, and a NEAR wallet.

## Tests and other examples

- [Cassandra Network Partition Test](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/cassandra-network-partition-test) - A test written in Kurtosis Starlark & Golang that verifies Cassandra's behavior under network failure using the [cassandra-package](https://github.com/kurtosis-tech/cassandra-package)
- [Ethereum Network Partition Test](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/ethereum-network-partition-test) - A test that verifies how the Ethereum network behaves under network partitioning. The test is written in both Golang and Starlark.
- [Quick Start](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/quickstart) - The example used in the [Quickstart guide](https://docs.kurtosis.com/quickstart) to get started with Kurtosis.
- [Simple NodeJS API](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/simple-api) - An example of how a Simple NodeJS based API can be setup to test using Kurtosis
- [Data Package](https://github.com/kurtosis-tech/awesome-kurtosis/tree/main/data-package) - An example package that contains a tar that you can import and use within the Quickstart and other packages
- [Redis Voting App](./redis-voting-app) - An example package highlighting composition in Kurtosis that uses the [redis-package](https://github.com/kurtosis-tech/redis-package) and [Azure Voting Front](https://github.com/Azure-Samples/azure-voting-app-redis/tree/master/azure-vote) to spin up a voting app backed by Redis.
