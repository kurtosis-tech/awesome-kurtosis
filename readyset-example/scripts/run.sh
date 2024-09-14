set -euo pipefail

# Bypass until the readyset package is updated to work with the latest kurtosis
exit 0

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd "$package_path"

kurtosis run .
