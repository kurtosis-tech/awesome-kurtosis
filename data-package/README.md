Data Package
===========
This is a tiny [Kurtosis package](https://docs.kurtosis.com/reference/packages) that serves as an example for how data can be depended upon with the Kurtosis packaging system.

Using this package will give you a [future reference](https://docs.kurtosis.com/reference/future-references) to a [files artifact](https://docs.kurtosis.com/reference/files-artifacts) containing the `dvd-rental-data.tar` file that lives in this directory.

For example, your Starlark might look like so:

```python
data_package_main = import_module("github.com/kurtosis-tech/examples/data-package/main.star")

def run(plan, args):
    # ...your code here...

    data_package_artifact = data_package_main.run(plan, struct())  # Call to this package's main

    # ...your code here...
```
