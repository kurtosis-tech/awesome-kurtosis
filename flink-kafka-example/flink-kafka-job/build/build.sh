#!/usr/bin/env bash
# 2021-07-08 WATERMARK, DO NOT REMOVE - This script was generated from the Kurtosis Bash script template

set -euo pipefail   # Bash "strict mode"
script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==================================================================================================
#                                             Constants
# ==================================================================================================


# ==================================================================================================
#                                       Arg Parsing & Validation
# ==================================================================================================



# ==================================================================================================
#                                             Main Logic
# ==================================================================================================

docker build . --tag "kurtosis-tech/flink-kafka-example"

## Argument processing
##if "${push_to_registry_container}"; then
##  buildx_platform_arg='linux/arm64/v8,linux/amd64'
##  push_flag='--push'
##else
#  buildx_platform_arg='linux/arm64' # TODO: infer the local arch if that's reasonable
#  push_flag='--load'
##fi
##echo "Building docker image for architecture '${buildx_platform_arg}' with flag '${push_flag}'"
#
#docker_buildx_cmd="docker buildx build ${push_flag} --platform ${buildx_platform_arg} ${image_tags_concatenated} -f ${dockerfile_filepath} ${dockerfile_dirpath}"
#echo "Running the following docker buildx command:"
#echo "${docker_buildx_cmd}"
#if ! eval "${docker_buildx_cmd}"; then
#  echo "Error: Docker build failed" >&2
#  exit 1
#fi