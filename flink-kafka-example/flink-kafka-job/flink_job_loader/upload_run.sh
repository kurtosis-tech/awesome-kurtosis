#!/usr/bin/env bash
# 2021-07-08 WATERMARK, DO NOT REMOVE - This script was generated from the Kurtosis Bash script template

set -euo pipefail   # Bash "strict mode"

# ==================================================================================================
#                                             Constants
# ==================================================================================================


# ==================================================================================================
#                                       Arg Parsing & Validation
# ==================================================================================================

if [ -z "${FLINK_HOST}" ]; then
  echo "Error: No FLINK_HOST environment variable is set" >&2
  exit 1
fi

if [ -z "${FLINK_API_PORT}" ]; then
  echo "Error: No FLINK_API_PORT environment variable is set" >&2
  exit 1
fi

if [ -z "${RUN_JAR}" ]; then
  echo "Error: No RUN_JAR environment variable is set" >&2
  exit 1
fi

# ==================================================================================================
#                                             Main Logic
# ==================================================================================================

FLINK="${FLINK_HOST}:${FLINK_API_PORT}"
echo "Using ${FLINK} as the connection"

## Upload jar to Flink
echo "Uploading the jar file to Flink"
curl -X POST -H "Expect:" -F "jarfile=@${RUN_JAR}" "http://${FLINK}/jars/upload"
echo "Uploading the jar succeeded"

## Get the jar id
echo "Getting the jar id from Flink"
JAR_ID=$(curl -X GET "http://${FLINK}/jars/" | jq -cr '.files[0].id')

## Run the jar on the Flink cluster
echo "Running the jar on Flink"
curl -X POST "http://${FLINK}/jars/${JAR_ID}/run?program-args=--input-topic%20words%20--output-topic%20words-counted%20--group-id%20flink-kafka-example%20--bootstrap.servers%20kafka%3A9092"

