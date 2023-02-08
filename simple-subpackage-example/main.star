lib = import_module("github.com/kurtosis-tech/simple-subpackage-example/hello-world/lib/lib.star")

def run(plan):
    plan.print(lib.say_hello_world())
