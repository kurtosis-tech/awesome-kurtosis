#!/usr/bin/env sh

curl -X POST -H "Expect:" -F "jarfile=@run.jar" http://localhost:8081/jars/upload

JAR_ID=$(curl -X GET http://localhost:8081/jars/ | jq -cr '.files[0].id')

curl --location --request POST "http://localhost:8081/jars/${JAR_ID}/run?program-args=--input-topic%20words%20--output-topic%20words-counted%20--group-id%20flink-kafka-example%20--bootstrap.servers%20kafka%3A9092"

