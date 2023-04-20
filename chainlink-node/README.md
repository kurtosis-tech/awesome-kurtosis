Chainlink node
==============

This package starts a Chainlink nodes. It follows the steps from the official Chainlink documentation [here](https://docs.chain.link/chainlink-nodes/v1/running-a-chainlink-node)

#### Prerequisite
If you're running on a Mac, since Chainlink doesn't publish Docker images for mac, you will have to force docker to download the image for a different architecture by running:
```
docker pull --platform linux/amd64 smartcontract/chainlink:1.13.1
```
Once this finishes, the image will be cached in the local Docker engine.

#### Running a Chainlink node
The WSS and HTTP url of the chain to follow can be input filling the `args.json` file with your own values, and then running:
```
cd ./chainlink-node/
kurtosis run . "$(cat args.json)"
```

Once this has successfully run, you can go to the landing page of Chainlink by getting the port of the `chainlink` user service inside the enclave and opening the browser on `localhost:<PORT_NUMBER>`

Kurtosis will automatically create an account with the following credentials:
```
username: apiuser@chainlink.test
password: 16charlengthp4SsW0rD1!@#_
```


