set -euo pipefail

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd $package_path

yarn
kurtosis run github.com/kurtosis-tech/eth-network-package --enclave hardhat-enclave

PORT=$(kurtosis enclave inspect hardhat-enclave | grep el-client-0 | grep rpc | grep -oh "127.0.0.1\:\d*" | cut -d':' -f2)

sed -i 's/<PORT>/${PORT}/' hardhat.config.ts

npx hardhat balances --network localnet

npx hardhat compile
npx hardhat run scripts/deploy.ts --network localnet
