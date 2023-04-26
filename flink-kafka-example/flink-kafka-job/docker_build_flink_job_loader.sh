#!/usr/bin/env bash
# 2021-07-08 WATERMARK, DO NOT REMOVE - This script was generated from the Kurtosis Bash script template

set -euo pipefail   # Bash "strict mode"
script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ==================================================================================================
#                                             Constants
# ==================================================================================================
IMAGE="kurtosistech/flink-kafka-example-job-loader"
APPLICATION_NAME="flink_job_loader"

# ==================================================================================================
#                                       Arg Parsing & Validation
# ==================================================================================================

# ==================================================================================================
#                                             Main Logic
# ==================================================================================================
bash "${script_dirpath}/scripts/build.sh"
#cp "${script_dirpath}/build/run.jar" "${script_dirpath}/${APPLICATION_NAME}/run.jar"

docker build -f "${script_dirpath}/${APPLICATION_NAME}/." --tag "$IMAGE" .