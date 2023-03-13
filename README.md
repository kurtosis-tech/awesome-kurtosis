# Awesome Kurtosis [![Awesome](https://awesome.re/badge.svg)](https://awesome.re)

<img src="./logo.png" width="500">

> A curated list of Kurtosis Starlark Packages

These Kurtosis packages and examples provide a starting point for how to setup and test different environments using a Kurtosis Stalrlark package and
to manage their lifetime using the Kurtosis CLI.

> **Note**
> The following samples are intended for use in local development and testing environments. These samples must not be deployed in production environments.

## Contents

- [Kurtosis Starlark Packages in the Web2 Space](#kurtosis-starlark-web2-examples)
- [Kurtosis Starlark Packages in the Web3 Space](#kurtosis-starlark-web3-examples)
- [Tests and other examples](#tests-and-other-examples)

## Kurtosis Starlark Web2 Examples

- [Cassandra Package](https://github.com/kurtosis-tech/cassandra-package) - A Kurtosis Starlark Package that spins up an n node Cassandra cluster and verifies that the cluster that was spun up was healthy
- [Datastore Army Package](https://github.com/kurtosis-tech/datastore-army-package) - A Kurtosis Starlark Package that spins up an n node Datastore server cluster

## Kurtosis Starlark Web3 Examples

- [eth2 Package](https://github.com/kurtosis-tech/eth2-package) - A Kurtosis Starlark Package that spins up a local Ethereum testnet, supporting supporting 9 different EL and CL clients including geth, lighthouse, lodestar, nimbus and erigon.
- [near Package](https://github.com/kurtosis-tech/near-package) - A Kurtosis Starlark package that spins up a local near testnet with an indexer, wallet, explorer and more.

## Tests and other examples

- [Cassandra Network Partition Test](https://github.com/kurtosis-tech/examples/tree/main/cassandra-network-partition-test) - A test written in Kurtosis Starlark that verifies Cassandra's behavior under network failure using the [cassandra-package](https://github.com/kurtosis-tech/cassandra-package)
- [Ethereum Network Partition Test](https://github.com/kurtosis-tech/examples/tree/main/ethereum-network-partition-test) - A test that verifies how the Ethereum network behaves under network partitioning. The test is written in both Golang and Starlark.
- [Quick Start](https://github.com/kurtosis-tech/examples/tree/main/quickstart) - The example used by the [Quickstart guide](https://docs.kurtosis.com/quickstart) to quickly onboard a user to Kurtosis
- [Simple NodeJS API](https://github.com/kurtosis-tech/examples/tree/main/simple-api) - An example of how a Simple NodeJS based API can be setup to test using Kurtosis

