Ethereum Network Partitioning Example
=====================================
This demo shows off how Kurtosis network partitioning using proof-of-work mining Ethereum nodes.

NOTE 1: As of 2022-08-03, network partitioning isn't yet built for the Kubernetes backend, so this should be done with Docker.

NOTE 2: This uses the heavyweight proof-of-work mining nodes, so it's slow (but true-to-mainnet)

### Demo Flow
1. Make sure you have a Kurtosis engine running
1. Run the Go test inside of `main_test.go` (can be done with Goland)
1. Notice how:
    - A new Kurtosis enclave is created (run `kurtosis enclave ls`)
    - Ethereum containers get started inside Docker
    - The three Ethereum nodes are in agreement on the block tip hash:
      ```
      bootnode                 block number: 6, block hash: 0x856d09c24d8cc8a2fed87b961c5084b4f1bc9857654a8bd186d6fc74a6c90ab3
      ethereum-node-1          block number: 6, block hash: 0x856d09c24d8cc8a2fed87b961c5084b4f1bc9857654a8bd186d6fc74a6c90ab3
      ethereum-node-2          block number: 6, block hash: 0x856d09c24d8cc8a2fed87b961c5084b4f1bc9857654a8bd186d6fc74a6c90ab3
      ```
1. Shell into the `bootnode` (can be done with `kurtosis service shell`)
1. On the bootnode, run the following to have `bootnode` start pinging `ethereum-node-2`:
   ```
   apk update && apk add curl && while true; do curl --connect-timeout 3 -XGET -H "content-type: application/json" "http://ethereum-node-2:8545" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'; sleep 1; done
   ```
1. Wait until the network partition is induced (60 seconds from the start of the test, when `------------ INDUCING PARTITION ---------------` shows up in the test logs)
1. Notice how:
    - `bootnode` and `ethereum-node-1` continue to agree on block hash (because they can talk to each other) while `ethereum-node-2` no longer agrees on the block hash (because it's sectioned off from `bootnode` and `ethereum-node-1`):
      ```
      bootnode                 block number: 18, block hash: 0xce71716d24526ba8e70210de661b13c07d97ddb86d57e3c0395477a04463f1b5
      ethereum-node-1          block number: 18, block hash: 0xce71716d24526ba8e70210de661b13c07d97ddb86d57e3c0395477a04463f1b5
      ethereum-node-2          block number: 15, block hash: 0xbd7eaaa94f96d3754bfb194e8ade50d46964fe9ab26bce4e970b50239a33e562
      ```
    - The `curl` command running on the `bootnode` starts timing out as it attempts to ping `ethereum-node-2`:
      ```
      {"jsonrpc":"2.0","id":1,"result":"0xe"}
      {"jsonrpc":"2.0","id":1,"result":"0xe"}
      {"jsonrpc":"2.0","id":1,"result":"0xe"}
      {"jsonrpc":"2.0","id":1,"result":"0xe"}
      curl: (28) Connection timeout after 3002 ms
      curl: (28) Connection timeout after 3000 ms
      curl: (28) Connection timeout after 3001 ms
      ```
1. Wait until the network partition is healed (when `------------ HEALING PARTITION ---------------` shows up in the test logs)
1. Notice how:
    - All the nodes agree once more on the block hash (will take a little bit):
      ```
      bootnode                 block number: 23, block hash: 0x4e44e9ce3aadff408e1758d3e53250b85a28b83fa8d722a4826c056407301957
      ethereum-node-1          block number: 23, block hash: 0x4e44e9ce3aadff408e1758d3e53250b85a28b83fa8d722a4826c056407301957
      ethereum-node-2          block number: 23, block hash: 0x4e44e9ce3aadff408e1758d3e53250b85a28b83fa8d722a4826c056407301957
      ```
    - The `curl` command on `bootnode` returns to being able to reach `ethereum-node-2`:
      ```
      curl: (28) Connection timeout after 3002 ms
      curl: (28) Connection timeout after 3000 ms
      curl: (28) Connection timeout after 3000 ms
      {"jsonrpc":"2.0","id":1,"result":"0x14"}
      {"jsonrpc":"2.0","id":1,"result":"0x14"}
      {"jsonrpc":"2.0","id":1,"result":"0x14"}
      ```
