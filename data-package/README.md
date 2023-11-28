Data Package
===========
This is a tiny [Kurtosis package](https://docs.kurtosis.com/advanced-concepts/packages) that serves as an example for how data can be depended upon with the Kurtosis packaging system.

Using this package will give you a [future reference](https://docs.kurtosis.com/advanced-concepts/future-references) to a [files artifact](https://docs.kurtosis.com/basic-concepts/#files-artifact) containing the `dvd-rental-data.tar` file that lives in this directory.

For example, your Starlark might look like so:

```python
data_package_main = import_module("github.com/kurtosis-tech/awesome-kurtosis/data-package/main.star")

def run(plan, args):
    # ...your code here...

    data_package_info = data_package_main.run(plan, struct())  # Call to this package's main

    data_package_info.files_artifact  # Use this in add_service
    data_package_info.tar_filename    # Use this for referencing the TAR inside the files artifact

    # ...your code here...
```
