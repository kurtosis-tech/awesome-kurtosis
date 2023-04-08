#!/usr/bin/env bash
# Copyright (c) 2023 - present Kurtosis Technologies Inc.
# All Rights Reserved.

set -euo pipefail   # Bash "strict mode"
script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dirpath="$(dirname "${script_dirpath}")"
build_dirpath="${root_dirpath}/lib"

# ==================================================================================================
#                                             Constants
# ==================================================================================================


# =============================================================================
#                                 Main Code
# =============================================================================
# Checks if dockerignore file is in the root path

if [ ! -d "${root_dirpath}" ]; then
    echo "Error: Project root directory not set: '${root_dirpath}'" >&2
    exit 1
fi

cd "$root_dirpath" && sbt assembly

uber_jar_file="${root_dirpath}/target/scala-2.12/run.jar"
if ! [ -f "${uber_jar_file}" ]; then
    echo "Error: No build jar (uber jar) was found at expected path: '${uber_jar_file}'" >&2
    exit 1
fi

mkdir -p "${build_dirpath}"
cp "${uber_jar_file}" "${build_dirpath}"
build_jar_file="${build_dirpath}/run.jar"
if ! [ -f "${build_jar_file}" ]; then
    echo "Error: No build jar (uber jar) was found at expected path: '${build_jar_file}'" >&2
    exit 1
fi

echo "Successfully copied uber jar to build directory: ${build_jar_file}"
