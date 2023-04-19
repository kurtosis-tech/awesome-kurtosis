set -euo pipefail

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd $package_path
kurtosis run "${package_path}/main.star" --with-subnetworks

cd "${package_path}/go-test"
go test -timeout 15m  -v

cd "${package_path}/ts-test"
npm install -g yarn
yarn install
yarn build
yarn test
