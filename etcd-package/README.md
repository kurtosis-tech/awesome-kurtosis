## Etcd Package

This is a [Kurtosis Starlark Package](https://docs.kurtosis.com/quickstart) that allows you to spin up an etcd instance.

### Run

This assumes you have the [Kurtosis CLI](https://docs.kurtosis.com/cli) installed

Simply run

```bash
kurtosis run github.com/kurtosis-tech/awesome-kurtosis/etcd-package
```

### Using this in your own package

Kurtosis Packages can be used within other Kurtosis Packages, through what we call composition internally. Assuming you want to spin up etcd and your own service
together you just need to do the following

```py
main_etcd_module = import_module("github.com/kurtosis-tech/awesome-kurtosis/etcd-package/main.star")

# main.star of your etcd + Service package
def run(plan, args):
    plan.print("Spinning up the etcd Package")
    # this will spin up etcd and return the output of the etcd package
    etcd_run_output = main_redis_module.run(plan, args)
```
