#!/usr/bin/env bash
# 2021-07-08 WATERMARK, DO NOT REMOVE - This script was generated from the Kurtosis Bash script template

# Created this script for running all packages locally
set -euo pipefail   # Bash "strict mode"
skip_dirs=(".circleci/ .github/ data-package/")
for directory in */ ; do
  if ! echo "$skip_dirs" | grep -q "$directory"; then
    "./${directory}scripts/run.sh"
    kurtosis clean -a
  fi
done
echo "termino"
