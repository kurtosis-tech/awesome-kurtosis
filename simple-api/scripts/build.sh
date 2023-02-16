#!/usr/bin/env bash
# Copyright (c) 2023 - present Kurtosis Technologies Inc.
# All Rights Reserved.

set -euo pipefail   # Bash "strict mode"
script_dirpath="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
package_dirpath="$(dirname "${script_dirpath}")"
server_dirpath="${package_dirpath}/server"

# ==================================================================================================
#                                             Constants
# ==================================================================================================
DOCKER_TAG="latest"
APPLICATION="kurtosis-simple-api"
IMAGE_ORG_AND_REPO="kurtosistech/${APPLICATION}"

# =============================================================================
#                                 Main Code
# =============================================================================
# Checks if dockerignore file is in the root path
if ! [ -f "${package_dirpath}"/.dockerignore ]; then
  echo "Error: No .dockerignore file found in ${APPLICATION} root '${package_dirpath}'; this is required so Docker caching is enabled and the image builds remain quick" >&2
  exit 1
fi

# Build Docker image
dockerfile_filepath="${server_dirpath}/Dockerfile"
image_name="${IMAGE_ORG_AND_REPO}:${DOCKER_TAG}"
echo "Building files into a Docker image named '${image_name}' using docker file in ${dockerfile_filepath}..."
if ! docker build -t "${image_name}" -f "${dockerfile_filepath}" "${package_dirpath}"; then
  echo "Error: Docker build of the ${APPLICATION} failed" >&2
  exit 1
fi
echo "Successfully built Docker image '${image_name}' containing the ${APPLICATION}"

