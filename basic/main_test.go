package main

import (
	"github.com/sirupsen/logrus"
	"testing"
)

/*
This example will:
1. Start an Ethereum network with `numParticipants` nodes
2. Wait for all the nodes to be synced
3. Partition the network into 2. Half of the nodes will be in partition 1, half will be in partition 2
4. Wait for the block production to diverge in each partition
5. Heal the partition and wait for all nodes to get back in sync

This test demonstrate Ethereum-forking behaviour in Kurtosis.
*/

const (
	logLevel = logrus.InfoLevel

	enclaveId = "basic-unit-test-example"
)

func TestBasicUnitTest(t *testing.T) {

	logrus.Info("----------- Starting --------------")
}
