script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd $package_path

yarn
kurtosis run github.com/kurtosis-tech/eth-network-package
npx hardhat balances --network localnet

npx hardhat compile
npx hardhat run scripts/deploy.ts --network localnet
