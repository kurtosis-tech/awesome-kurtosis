script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_path="$(dirname "${script_dirpath}")"

cd $package_path
kurtosis run "${package_path}/main.star" --with-subnetworks
go test -timeout 5m  -v
