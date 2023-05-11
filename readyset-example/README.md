Readyset Example
===============

## Overview

This example demonstrates the [Kurtosis Readyset package](https://github.com/kurtosis-tech/readyset-package) in action. We have automated the Readyset's [quickstart](https://docs.readyset.io/guides/intro/quickstart/) and showcase how Kurtosis can be useful, especially for integration and end-to-end testing use cases.

In this example, we use Kurtosis to set up isolated and repeatable environment that contains three services: Postgres, Readyset, and Benchmark. The package does the following:

1. It first spins up a Postgres database with initial seed data, which can be found in the `seed` folder.
2. It then spins up a Readyset service and waits until it finishes snapshotting all the tables found in the Postgres database.
3. It spins up a Benchmark service, installs necessary dependencies, and executes the Python script available in the Quickstart documentation against the Postgres database.
4. We create a cached query in Readyset and execute the Python script again.
5. Finally, we return the performance benchmark output for Postgres and Readyset.

Environments defined in your GitHub repository, such as this one, can run on your local laptop or CI, or in the cloud ephemerally using Kurtosis. If you're interested in our cloud offering and want to learn how to deploy and run services with ReadySet on the cloud, please reach out to us or fill out the [form](https://mp2k8nqxxgj.typeform.com/to/U1HcXT1H).

## Running Kurtosis Package

To run the example, first, ensure that you have the latest version of the Kurtosis CLI installed. You can do this by [following the installation guide](https://docs.kurtosistech.com/install) and then running the command:

```shell
kurtosis run --enclave readyset-perf github.com/kurtosis-tech/awesome-kurtosis/readyset-example
```

<details>
<summary> <b>Click here to see expected output after the package is ran successfully </b></summary>

```shell
Starlark code successfully run. Output was:
{
	"postgres_output": "
Result:
['count']
['2418']

Query latencies (in milliseconds):
['43.97', '30.72', '27.59', '26.86', '27.73', '28.66', '29.91', '30.18', '27.58', '28.39', '27.90', '27.56', '27.76', '27.79', '27.88', '28.78', '27.02', '27.14', '27.15', '28.40']

Latency percentiles (in milliseconds):
 p95: 31.38

",
	"readyset_output": "
Result:
['count(coalesce(`public`.`title_ratings`.`tconst`, 0))']
['2418']

Query latencies (in milliseconds):
['46.59', '1.69', '0.31', '0.32', '0.27', '0.25', '0.26', '0.25', '0.24', '0.24', '0.25', '0.24', '0.24', '0.25', '0.24', '0.23', '0.24', '0.25', '0.25', '0.27']

Latency percentiles (in milliseconds):
 p95: 3.94

"
}
INFO[2023-05-11T02:28:43-04:00] ==================================================== 
INFO[2023-05-11T02:28:43-04:00] ||          Created enclave: readyset-perf          || 
INFO[2023-05-11T02:28:43-04:00] ==================================================== 
Name:            readyset-perf
UUID:            0b38c17bd505
Status:          RUNNING
Creation Time:   Thu, 11 May 2023 02:26:38 EDT

========================================= Files Artifacts =========================================
UUID           Name
035d39bd4a27   app
ee3f3f51e90e   postgres_seed_file

========================================== User Services ==========================================
UUID           Name        Ports                                                      Status
506d7165163a   benchmark   <none>                                                     RUNNING
805860c10379   postgres    postgresql: 5432/tcp -> postgresql://127.0.0.1:50322       RUNNING
1bdd453c8181   readyset    ready_set_port: 5433/tcp -> postgresql://127.0.0.1:50326   RUNNING
```
</details>

## Connecting Readyset to remote database

Kurtosis supports parametrization, which allows us to configure ReadySet to connect to PostgreSQL, MySQL, or any remote database.

The following snippet provides a brief introduction on how different modular packages can be stitched together to construct complex and well-defined environments.

```python
readyset = import_module("github.com/kurtosis-tech/readyset-package")

def run(plan):
    readyset_output = readyset.run(plan, {"upstream_db_url": "postgresql://postgres:readyset@hostname/test"})

    env_vars = {"CACHE_URL": readyset_output.url}
    # services that depend on readyset can be added here like follows
    # for more information go to our documentation here:
    plan.add_service(..., ServiceConfig(..., env_vars=env_vars))

```

To see it in action, run the following command. We have added support for connecting to a remote database. If you want to connect to a remote database, set upstream_db_url or it will default to the behaviour seen above.

```shell
kurtosis run --enclave readyset-remote github.com/kurtosis-tech/awesome-kurtosis/readyset-example '{"upstream_db_url": "postgresql://postgres:readyset@hostname/test"}'
```

After running Kurtosis package, you should an output similar to the one shown below:
```
INFO[2023-05-11T02:28:43-04:00] ==================================================== 
INFO[2023-05-11T02:28:43-04:00] ||          Created enclave: readyset-perf          || 
INFO[2023-05-11T02:28:43-04:00] ==================================================== 
...
...
...
========================================== User Services ==========================================
UUID           Name        Ports                                                      Status
1bdd453c8181   readyset    ready_set_port: 5433/tcp -> postgresql://127.0.0.1:50326   RUNNING
```

You can use the above information to connect to readyset service via psql (or mysql if readyset is running against it) as shown below:
```
PGPASSWORD=readyset psql --host=127.0.0.1 --port=50326 --username=postgres --dbname=test
```

## Running Readyset with MySQL database

In this example, you can add a MySQL database through composability and parameterization. You can use the [Kurtosis MySQL package available here](https://github.com/kurtosis-tech/mysql-package) and integrate it into the example in a similar way to the [Postgres package](https://github.com/kurtosis-tech/postgres-package). Although we have not yet added support for it, we encourage you to give it a try. We have also included some comments in the code to help guide you.