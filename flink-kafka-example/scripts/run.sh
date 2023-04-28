set -euo pipefail

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")/kurtosis-package"

cd "$package_path"

kurtosis run .

