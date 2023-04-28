#!/usr/bin/env bash
# Copyright (c) 2023 - present Kurtosis Technologies Inc.
# All Rights Reserved.

set -euo pipefail   # Bash "strict mode"
script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dirpath="$(dirname "${script_dirpath}")"
build_dirpath="${root_dirpath}/build"

# Note you'll need Java (>=v11) and sbt installed before running this script

# ==================================================================================================
#                                             Constants
# ==================================================================================================
SBT_BUILD_PATH="target/scala-2.12"
JAR_BUILD_FILE_NAME="run.jar"

# =============================================================================
#                                 Main Code
# =============================================================================
if [ ! -d "${root_dirpath}" ]; then
    echo "Error: Project root directory not set: '${root_dirpath}'" >&2
    exit 1
fi

cd "$root_dirpath" && sbt "clean;assembly"

uber_jar_file="${root_dirpath}/${SBT_BUILD_PATH}/${JAR_BUILD_FILE_NAME}"
if ! [ -f "${uber_jar_file}" ]; then
    echo "Error: No build jar was found at expected path: '${uber_jar_file}'" >&2
    exit 1
fi

mkdir -p "${build_dirpath}"
cp "${uber_jar_file}" "${build_dirpath}"
build_jar_file="${build_dirpath}/${JAR_BUILD_FILE_NAME}"
if ! [ -f "${build_jar_file}" ]; then
    echo "Error: No build jar was found after copying to: '${build_jar_file}'" >&2
    exit 1
fi

echo "Successfully copied jar to directory: ${build_jar_file}"
