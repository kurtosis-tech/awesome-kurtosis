## Redis Voting App

To get the voting app up and running use 

```
kurtosis run github.com/kurtosis-tech/awesome-kurtosis/redis-voting-app
```

If you have this repository cloned locally and are playing with the package, use

```
cd redis-voting-app
kurtosis run .
```

Once the package is up and running use the localhost binding of the `http` port for the `voting-app`; like


```bash
$ kurtosis run .
INFO[2023-03-21T12:42:52+01:00] Creating a new enclave for Starlark to run inside...
INFO[2023-03-21T12:42:55+01:00] Enclave 'watchful-pond' created successfully
INFO[2023-03-21T12:42:55+01:00] Executing Starlark package at '/Users/gyanendramishra/work/awesome-kurtosis/redis-voting-app' as the passed argument '.' looks like a directory
INFO[2023-03-21T12:42:55+01:00] Compressing package 'github.com/kurtosis-tech/awesome-kurtosis/redis-voting-app' at '.' for upload
INFO[2023-03-21T12:42:55+01:00] Uploading and executing package 'github.com/kurtosis-tech/awesome-kurtosis/redis-voting-app'

> print msg="Spinning up the Redis Package"
Spinning up the Redis Package

> add_service service_name="redis" config=ServiceConfig(image="redis:alpine", ports={"client": PortSpec(number=6379, transport_protocol="TCP")})
Service 'redis' added with service UUID '834941f5f4534842b0284ba75fb0fd78'

> add_service service_name="voting-app" config=ServiceConfig(image="mcr.microsoft.com/azuredocs/azure-vote-front:v1", ports={"http": PortSpec(number=80, transport_protocol="TCP")}, env_vars={"REDIS": "{{kurtosis:b521b1d157f7477d885edea315897a96:hostname.runtime_value}}"})
Service 'voting-app' added with service UUID 'ddc92486c1674d168f84380cfa739e5a'

Starlark code successfully run. No output was returned.
INFO[2023-03-21T12:43:03+01:00] ======================================================
INFO[2023-03-21T12:43:03+01:00] ||          Created enclave: watchful-pond          ||
INFO[2023-03-21T12:43:03+01:00] ======================================================
Name:            watchful-pond
UUID:            daa5cee9d3ba
Status:          RUNNING
Creation Time:   Tue, 21 Mar 2023 12:42:52 CET

========================================== User Services ==========================================
UUID           Name         Ports                                 Status
834941f5f453   redis        client: 6379/tcp -> 127.0.0.1:64699   RUNNING
ddc92486c167   voting-app   http: 80/tcp -> 127.0.0.1:64702       RUNNING
```

In the above example, you should copy `127.0.0.1:64702` and pop it into browser that you prefer.