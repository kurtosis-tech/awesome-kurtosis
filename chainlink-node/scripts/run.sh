set -euo pipefail

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd $package_path
echo "WARNING - This currently run in dry-run mode because we need a set of API keys to connect to Sepolia"
echo "This will be fixed once we plug the chainlink node to a local ethereum network spun up by Kurtosis"

kurtosis run . "$(cat args.json)"
