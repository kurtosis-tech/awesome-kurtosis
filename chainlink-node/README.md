Chainlink node
==============

This package starts a Chainlink node, a local multi-client Ethereum testnet, and connects the two. Modifying `args.json` on startup allows end-users to optionally link their Chainlink node into any other network (e.g. Goerli, Sepolia via a node provider like Alchemy or Avalanche's C-Chain subnet on the Fuji testnet).

This package was written by automating the setup steps from the official Chainlink documentation [here](https://docs.chain.link/chainlink-nodes/v1/running-a-chainlink-node) via Kurtosis.

#### Prerequisite
If you're running on a Mac you will have to force docker to download the image for a different architecture by running:
```
docker pull --platform linux/amd64 smartcontract/chainlink:1.13.1
```
Once this finishes, the image will be cached in the local Docker engine. This is because Chainlink doesn't publish Docker images for Mac yet.

#### Running a Chainlink node
Clone this repository locally and `cd` into the `/chainlink-node` folder: 
```
git clone https://github.com/kurtosis-tech/awesome-kurtosis.git && cd awesome-kurtosis/chainlink-node/
```
Then edit the `args.json` file to configure the WSS and HTTP URL of the chain you wish to connect to (e.g. Goerli) before running:

```
kurtosis run . "$(cat args.json)"
```

Once this has successfully run, you can go to the landing page of Chainlink by getting the port of the `chainlink` user service inside the enclave and opening the browser on `localhost:<PORT_NUMBER>`

Kurtosis will automatically create an account with the following credentials:
```
username: apiuser@chainlink.test
password: 16charlengthp4SsW0rD1!@#_
```

### Running a local Ethereum network
To spin up the Chainlink node connected to a local Ethereum network, simply run the same commands as above but with empty values for the `wss_url` and `http_url` fields in the `args.json` file. Leave the `chain_id` field as it is to ensure the Chainlink node successfully connects to the CL client on your local Ethereum network. The local Ethereum network is a separate package defined as the "[eth-network-package](https://github.com/kurtosis-tech/eth-network-package)".

### Connecting it to Avalanche's C-chain subnet on the Fuji testnet 
Simply override the `args.json` file with the following data:
```json
{
    "chain_name": "Avalanche C-Chain on Fuji Testnet",
    "chain_id": "43113",
    "wss_url": "wss://api.avax-test.network/ext/bc/C/ws", 
    "http_url": "https://api.avax-test.network/ext/bc/C/rpc"
}
```

The `chain_id` and URLs are from the [official Avalanche Public API Server docs](https://docs.avax.network/apis/avalanchego/public-api-server#using-the-public-api-nodes).

### Running a local Avalanche Network

This is very similar to running a local ethereum network but instead of the `chain_id` being `3151908` it needs to be `43112`. The Avalanche package is [here](https://github.com/kurtosis-tech/avalanche-package)
