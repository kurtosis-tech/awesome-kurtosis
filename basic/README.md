Basic unit testing using Kurtosis
=====================================
This demo shows some common test scenarios a user of the Kurtosis SDK would experience.

### Scope

A common test flow is as follows: 

1. create an enclave
1. add a service
1. call the service to test or verify state
1. remove service
1. remove enclave

In the [Go test file](`./main_test.go`) you can find an example of the above flow using the Kurtosis Go SDK.