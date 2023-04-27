Chainlink node
==============

This package starts a Chainlink node, a local multi-client Ethereum testnet, and connects the two. Modifying `args.json` on startup allows end-users to optionally link their Chainlink node into any other network (e.g. Goerli, Sepolia via a node provider like Alchemy)

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

#### Running a local Ethereum network
To spin up the Chainlink node connected to a local Ethereum network, simply run the same commands as above but with empty values for the `wss_url` and `http_url` fields in the `args.json` file. Leave the `chain_id` field as it is to ensure the Chainlink node successfully connects to the CL client on your local Ethereum network. The local Ethereum network is a separate package defined as the "[eth-network-package](https://github.com/kurtosis-tech/eth-network-package)".

WARNING: This currently does not work with the `smartcontract/chainlink:1.13.1` docker image as this image prevents us from using `update-ca-certificates` inside the container to trust the self-signed certificate we use in NGINX in front of the ETH network. We had to build our own image at `gbouv/chainlink:1.13.1` which is strictly identical, but uses the root user by default so `update-ca-certificates` can be run and the Chainlink node can connect to the local ETH network through NGINX.

Note that Chainlink nodes can only connect to an Ethereum chain when the chain exposes encrypted endpoint. Because of this, the package also spins up an NGINX container with pre-loaded certificates and configured to proxy queries 
to one of the ethereum node.

Note: for now the certificates are self-signed certificates checked into  the repo under `./nginx/ssl/`. They have been generated with the following command on MacOS:
```
openssl req -x509 -nodes -addext "subjectAltName = DNS:nginx" -days 1461 -newkey rsa:2048 -keyout ./nginx/ssl/nginx.key -out ./nginx/ssl/nginx.crt
```
It's important to keep `nginx` as the DNS here as it's the hostname of the nginx container spun up inside the enclave. In the long term, the certificates should be generated with an openssl container and not be checked inside the repo.
