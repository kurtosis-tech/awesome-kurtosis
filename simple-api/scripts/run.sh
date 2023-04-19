script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

"./${script_dirpath}/build.sh"

cd "$package_path"

kurtosis run main.star
