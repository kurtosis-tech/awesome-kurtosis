set -euo pipefail

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")/kurtosis-package"

"${script_dirpath}/build.sh"

cd "$package_path"

kurtosis run .
