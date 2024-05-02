## Ethereum dApp and Smart Contract Development Example

This example demonstrates how Kurtosis can be used for local dApp and Smart Contract development
by using the [`eth-network-package`](https://github.com/kurtosis-tech/eth-network-package) as a local Ethereum network. 
The `eth-network package` can be used as a low overhead, configurable, and composable alternative to frameworks like
`hardhat-network`, `ganache` and `anvil`. Kurtosis provides the developer more control and flexibility over the testnet they are using - a large reason why the [Ethereum Foundation used Kurtosis to test the Merge](https://www.kurtosis.com/blog/testing-the-ethereum-merge), and why they continue to use Kurtosis for various tests for upcoming upgrades to the network.

While this example covers only the Ethereum blockchain, Kurtosis can be used to locally configure and instantiate other blockchains (e.g. [NEAR](https://github.com/kurtosis-tech/near-package), [Avalanche](https://medium.com/avalancheavax/introducing-kurtosis-a-complete-testing-platform-to-accelerate-development-on-avalanche-6ad7e1147791) and allows you to connect your local testnet with any containerized service you wish.

### Setup

This folder contains a typical setup for a dApp developer using the
[Hardhat](https://hardhat.org/) framework. Let's explore it's contents.
- `contracts/` contains a few simple smart contracts for a Blackjack dApp 
- `scripts/` contains a script to deploy a token contract to our local Ethereum network
- `test/` contains a simple test for our token contract
- `hardhat.config.ts` configures our Hardhat setup. 
It allows us to configure Hardhat to use a local Ethereum network created by the `eth-network-package`.

### Running the Example

This assumes you have the following services installed:
- [Docker](https://docs.kurtosis.com/install#i-install--start-docker) with the Docker daemon running
- [Kurtosis CLI](https://docs.kurtosis.com/cli/)
- [Node.js](https://nodejs.org/en), [yarn](https://classic.yarnpkg.com/lang/en/docs/install/#mac-stable), and [npx](https://www.npmjs.com/package/npx) (for our dApp environment)


1. To setup the dApp environment, simply run
    ```
    git clone https://github.com/kurtosis-tech/awesome-kurtosis.git
    cd awesome-kurtosis/smart-contract-example
    yarn
    ```
    This will clone the repository and install all the necessary dependencies.

2. Now, Run 
    ```
    kurtosis run github.com/kurtosis-tech/eth-network-package
    ```
    The output should look something like this
    ```
    ========================================== User Services ==========================================
    UUID           Name                                           Ports                                         Status
    bbccb71bf6db   cl-client-0-beacon                             http: 4000/tcp -> http://127.0.0.1:64256      RUNNING
                                                                  metrics: 5054/tcp -> http://127.0.0.1:64257   
                                                                  tcp-discovery: 9000/tcp -> 127.0.0.1:64258    
                                                                  udp-discovery: 9000/udp -> 127.0.0.1:59023    
    a4429f19d246   cl-client-0-validator                          http: 5042/tcp -> 127.0.0.1:64262             RUNNING
                                                                  metrics: 5064/tcp -> http://127.0.0.1:64263   
    77c853ab371b   el-client-0                                    engine-rpc: 8551/tcp -> 127.0.0.1:64246       RUNNING
                                                                  rpc: 8545/tcp -> 127.0.0.1:64248              
                                                                  tcp-discovery: 30303/tcp -> 127.0.0.1:64247   
                                                                  udp-discovery: 30303/udp -> 127.0.0.1:58705   
                                                                  ws: 8546/tcp -> 127.0.0.1:64249               
    0d8469f528c9   prelaunch-data-generator-1680298734419927594   <none>                                        STOPPED
    8828574730f6   prelaunch-data-generator-1680298734428736261   <none>                                        STOPPED
    a9ad4e4cc65c   prelaunch-data-generator-1680298734439099469   <none>                                        STOPPED
    ```
    We see a single node with a geth EL client and lighthouse CL client running has been created. The CL and EL client pair can be configured using a `.json` file. Currently, the Ethereum package supports lighthouse, nimbus, lodestar, teku, and prysm CL clients as well as the erigon, nethermind, besu, and geth EL clients. Read [here](https://github.com/kurtosis-tech/eth-network-package#configuring-the-network) to learn more. 
    Each EL and CL client requires data that differs per client, so we leverage the `prelaunch-data-generator`, built off this [Docker image](https://github.com/ethpandaops/ethereum-genesis-generator), to create the necessary genesis files and secrets.

3. Replace `<PORT>` in `hardhat.config.ts` with the port of the rpc uri output from any `el-client-<num>` service. In this case, the port would be `64248`.
    ```
    localnet: {
    url: 'http://127.0.0.1:<PORT>',//TODO: REPLACE PORT WITH THE PORT OF A NODE URI PRODUCED BY THE ETH NETWORK KURTOSIS PACKAGE
    // These are private keys associated with prefunded test accounts created by the eth-network-package
    // https://github.com/kurtosis-tech/eth-network-package/blob/main/src/prelaunch_data_generator/genesis_constants/genesis_constants.star
    accounts: [
        "ef5177cd0b6b21c87db5a0bf35d4084a8a57a9d6a064f86d51ac85f2b873a4e2",
        "48fcc39ae27a0e8bf0274021ae6ebd8fe4a0e12623d61464c498900b28feb567",
        "7988b3a148716ff800414935b305436493e1f25237a2a03e5eebc343735e2f31",
        "b3c409b6b0b3aa5e65ab2dc1930534608239a478106acf6f3d9178e9f9b00b35",
        "df9bb6de5d3dc59595bcaa676397d837ff49441d211878c024eabda2cd067c9f",
        "7da08f856b5956d40a72968f93396f6acff17193f013e8053f6fbb6c08c194d6",
      ],
    },
    ```
4. Run 
    ```
    npx hardhat balances --network localnet
    ``` 
    This verifies that network is working and detects the prefunded accounts on the network, created by the `eth-network-package`.
    The output should look something like this:
    ```
    0x878705ba3f8Bc32FCf7F4CAa1A35E72AF65CF766 has balance 10000000000000000000000000
    0x4E9A3d9D1cd2A2b2371b8b3F489aE72259886f1A has balance 10000000000000000000000000
    0xdF8466f277964Bb7a0FFD819403302C34DCD530A has balance 10000000000000000000000000
    0x5c613e39Fc0Ad91AfDA24587e6f52192d75FBA50 has balance 10000000000000000000000000
    0x375ae6107f8cC4cF34842B71C6F746a362Ad8EAc has balance 10000000000000000000000000
    0x1F6298457C5d76270325B724Da5d1953923a6B88 has balance 10000000000000000000000000
    ```
5. Now, we can run dev/test workflows against our network! For example, let's compile and deploy the `ChipToken` so we can iterate and test how things work locally:
    ```
    npx hardhat compile
    npx hardhat run scripts/deploy.ts --network localnet
    ```
    The output should look something like this
    ```
    ChipToken deployed to: 0xAb2A01BC351770D09611Ac80f1DE076D56E0487d
    ```