#!/usr/bin/env bash
# 2021-07-08 WATERMARK, DO NOT REMOVE - This script was generated from the Kurtosis Bash script template

set -euo pipefail   # Bash "strict mode"
script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dirpath="$(dirname "${script_dirpath}")"

# ==================================================================================================
#                                             Constants
# ==================================================================================================
IMAGE="kurtosistech/flink-kafka-example"
APPLICATION_NAME="flink_job_loader"

# ==================================================================================================
#                                       Arg Parsing & Validation
# ==================================================================================================

# ==================================================================================================
#                                             Main Logic
# ==================================================================================================
bash "${root_dirpath}/scripts/build.sh"
cp "${root_dirpath}/build/run.jar" "${root_dirpath}/${APPLICATION_NAME}/run.jar"

docker build "${root_dirpath}/${APPLICATION_NAME}/." --tag "$IMAGE"