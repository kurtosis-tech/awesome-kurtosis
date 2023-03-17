## Cassandra Network Partition Test

### Kurtosis Starlark Version

This test sets up an _N_ Node Cassandra Cluster (default _N_ = 3), and then moves the last node into a separate network partition, effectively
disconnecting the last node from the rest of the nodes in the Cassandra Cluster.

The test verifies that the Cluster became unhealthy, then it moves the last node to the same network as the rest of the nodes and verifies
that the cluster has healed.

To run:

```
kurtosis run github.com/kurtosis-tech/awesome-kurtosis/cassandra-network-partition-test --with-subnetworks
```

### Golang Version

This test sets up an _N_ Node Cassandra Cluster (default _N_ = 3), and then moves N/2 nodes into the first partition and the remaining nodes into
the second partition.

The  test verifies that post partitioning the number of nodes marked as "UN" from the two partitions are as expected. Then it heals the partitions
and verifies that the number of nodes seen as "UN" from both the partitions are the same and equal to the total number of nodes running.

To run

```
git clone https://github.com/kurtosis-tech/awesome-kurtosis.git
cd cassandra-network-partition-test/
go test -timeout 5m -v
```