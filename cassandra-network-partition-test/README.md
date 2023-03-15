## Cassandra Network Partition Test

This test sets up an N Node Cassandra Cluster (default N = 3), and then moves the last node into a separate network partition effectively
disconnecting the last node from the rest of the nodes in the Cassandra Cluster.

The test verifies that the Cluster became unhealthy, then it moves the last node to the same network as the rest of the nodes and verifies
that the cluster has healed.

To run:

```
kurtosis run github.com/kurtosis-tech/examples/cassandra-network-partition-test --with-subnetworks
```
