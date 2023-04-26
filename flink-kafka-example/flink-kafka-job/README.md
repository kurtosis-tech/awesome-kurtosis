# Kurtosis Flink Kafka Example

This repo contains two parts:
* A Flink job that can count words on a topic and emit the count to another topic
* A helper docker image that enables uploading a Flink job to a Flink jobmanager 

### Run

Use `run.jar` in `lib` folder.

## Building the Flink job

Before building the project you'll need the following installed (recommended versions)

* Java (11.0.18)
* sbt (1.8.2)

Once installed you can build the jar using this command:

```shell
bash scripts/docker_build_flink_job_loader.sh
```

## Building the FLink Job Loader

```shell
bash docker_build_flink_job_loader.sh
```