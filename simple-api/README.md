# Kurtosis Simple API Server

In this example we are providing a simple NodeJs based API server (found under `server/` ). There are two ways to run this example:

* Use the Kurtosis Simple API image in [DockerHub](https://hub.docker.com/repository/docker/kurtosistech/kurtosis-simple-api)
* Build the Kurtosis Simple API locally and upload to your local Docker Engine

## Running Kurtosis Simple API using prebuilt image on DockerHub

1. Clone this repo

```shell
$ git clone git@github.com:kurtosis-tech/examples.git
```

2. cd into the `simple-api` directory:

```shell
$ cd simple-api
```
3. The server can be run by checking out the repo and running the Kurtosis CLI:

```shell
$ kurtosis run kurtosis-package/kurtosis.yml --enclave-id kurtosis-enclave
```

which will output something similar to this once execution has completed:

```shell
$ kurtosis run kurtosis-package/kurtosis.yml --enclave-id kurtosis-enclave
INFO[2023-02-27T16:21:36-05:00] Creating a new enclave for Starlark to run inside... 
INFO[2023-02-27T16:21:38-05:00] Enclave 'kurtosis-enclave' created successfully 
INFO[2023-02-27T16:21:38-05:00] Executing Starlark package at '/Users/ads/code/kurtosis-tech/awesome-kurtosis/simple-api/kurtosis-package' as the passed argument 'kurtosis-package' looks like a directory
INFO[2023-02-27T16:21:38-05:00] Compressing package 'github.com/kurtosis-tech/awesome-kurtosis/kurtosis-simple-api' at 'kurtosis-package' for upload 
INFO[2023-02-27T16:21:38-05:00] Uploading and executing package 'github.com/kurtosis-tech/awesome-kurtosis/kurtosis-simple-api'

> print "Starting the simple-api package"
Starting the simple-api package

> add_service service_name="kurtosis-simple-api" config=ServiceConfig(image="kurtosistech/kurtosis-simple-api", ports={"http": PortSpec(number=8080, transport_protocol="TCP", application_protocol="http")})
Service 'kurtosis-simple-api' added with service UUID 'ddf04ab5ba64465d81de661a91aa7226'

> wait recipe=GetHttpRequestRecipe(port_id="http", endpoint="/health", extract="") field="code" assertion="IN" target_value=[200] timeout="30s" service_name="kurtosis-simple-api"
Wait took 3 tries (2.13371021s in total). Assertion passed with following:
Request had response code '200' and body "{\"status\":\"healthy\"}"

Starlark code successfully run. No output was returned.
INFO[2023-02-27T16:21:41-05:00] ========================================================= 
INFO[2023-02-27T16:21:41-05:00] ||          Created enclave: kurtosis-enclave          || 
INFO[2023-02-27T16:21:41-05:00] ========================================================= 

```

The logs show how the Kurtosis CLI is retrieving the Kurtosis simple API image that has already been uploaded to DockerHub 
as `kurtosistech/kurtosis-simple-api` and hereafter running the code in the Starlark script in `kurtosis-package/main.star`.
The code in the Starlark script first creates the service and afterwards waits until the service health check endpoint returns `200` (i.e. healthy).

4. Once the Kurtosis CLI finishes successfully you can retrieve the logs of the service by running this command:  

```shell
$ kurtosis service logs kurtosis-enclave kurtosis-simple-api
```

which will produce an output like this:

```shell
$ kurtosis service logs kurtosis-enclave kurtosis-simple-api
Server listening on the port::8080
```

5. Lastly we can inspect the contents of the enclave more closely by calling the `enclave inspect` command:

```shell
$ kurtosis enclave inspect kurtosis-enclave
```

which produces an output similar to this:

```shell
$ kurtosis enclave inspect kurtosis-enclave
UUID:                                 4d54d9238d72
Enclave Name:                         kurtosis-enclave
Enclave Status:                       RUNNING
Creation Time:                        Mon, 27 Feb 2023 16:21:36 EST
API Container Status:                 RUNNING
API Container Host GRPC Port:         127.0.0.1:50122
API Container Host GRPC Proxy Port:   127.0.0.1:50123

========================================== User Services ==========================================
UUID           Name                  Ports                                      Status
ddf04ab5ba64   kurtosis-simple-api   http: 8080/tcp -> http://127.0.0.1:50137   RUNNING
```

We can see that the `kurtosis-simple-api` service is listening on port 8080 on the container inside the enclave 
and that it's mapped to port `50137` outside of Docker.
This means that we can interact with the service using port `50137` as in this example (assuming `jq` is installed):

```shell
$ curl 'http://localhost:50137/api/v1/logs?service_uuid=13972c20f7d34b39b2ee75036778c9e3' | jq 
[
  {
    "service_name": "dynamodb",
    "service_uuid": "13972c20f7d34b39b2ee75036778c9e3",
    "log": "Initializing DynamoDB Local with the following configuration:"
  },
  {
    "service_name": "dynamodb",
    "service_uuid": "13972c20f7d34b39b2ee75036778c9e3",
    "log": "Port:\t8000"
  },
  {
    "service_name": "dynamodb",
    "service_uuid": "13972c20f7d34b39b2ee75036778c9e3",
    "log": "InMemory:\ttrue"
  },
  {
    "service_name": "dynamodb",
    "service_uuid": "13972c20f7d34b39b2ee75036778c9e3",
    "log": "DbPath:\tnull"
  },
  {
    "service_name": "dynamodb",
    "service_uuid": "13972c20f7d34b39b2ee75036778c9e3",
    "log": "SharedDb:\tfalse"
  },
  {
    "service_name": "dynamodb",
    "service_uuid": "13972c20f7d34b39b2ee75036778c9e3",
    "log": "shouldDelayTransientStatuses:\tfalse"
  },
  {
    "service_name": "dynamodb",
    "service_uuid": "13972c20f7d34b39b2ee75036778c9e3",
    "log": "CorsParams:\tnull"
  }
]
```

Note that services _inside_ the enclave must still use port 8080 to interact with the Kurtosis Simple API.

6. The enclave can be removed by running this command:

```shell
$ kurtosis enclave rm kurtosis-enclave --force
```

or by using the more indiscriminate alternative that will remove _all_ enclaves:

```shell
$ kurtosis clean -a
```
## Running Kurtosis by building Kurtosis Simple API locally

If you are unable to use Dockerhub, you can build the Kurtosis Simple API locally by running this command:

```shell
$ bash scripts/build.sh 
```

This will build and push the Kurtosis Simple API to your local Docker Engine. 
Note, if you build your image locally and then run the Kurtosis Simple API Starlark script (as described in the section above),
the Starlark engine will download the latest `kurtosistech/kurtosis-simple-api` image from Dockerhub and 
move the name and tag from your local build to this build from Dockerhub, thus leaving your local build unnamed and dangling.

If you wish to run your local build from the Starlark script you can build the image locally with a special tag and reference that tag in the Starlark script.

