set -euo pipefail

script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd $package_path
kurtosis run . '{"username": "abc", "password": "123", "database": "bd"}'
