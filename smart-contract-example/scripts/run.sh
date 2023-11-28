set -euo pipefail

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd $package_path

yarn
kurtosis run github.com/kurtosis-tech/ethereum-package  --enclave hardhat-enclave '{"network_params": {"capella_fork_epoch": 10}}'

PORT=$(kurtosis enclave inspect hardhat-enclave | grep "rpc: 8545/tcp" | grep -oh "127.0.0.1\:[0-9]*" | cut -d':' -f2)

sed -i "s/<PORT>/$PORT/" hardhat.config.ts

npx hardhat balances --network localnet

npx hardhat compile
# TODO fix this so that a re-run isn't required
npx hardhat run scripts/deploy.ts --network localnet || npx hardhat run scripts/deploy.ts --network localnet
