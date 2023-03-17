package main

import (
	"context"
	"fmt"
	"github.com/kurtosis-tech/kurtosis/api/golang/core/lib/enclaves"
	"github.com/kurtosis-tech/kurtosis/api/golang/core/lib/services"
	"github.com/kurtosis-tech/kurtosis/api/golang/engine/lib/kurtosis_context"
	"github.com/kurtosis-tech/stacktrace"
	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/require"
	"sort"
	"strconv"
	"strings"
	"testing"
	"time"
)

/*
This example will:
1. Start a Cassandra network with `numNodes` nodes
2. Wait for all nodes to be healthy
3. Partition the network into 2. Half of the nodes will be in partition 1, half will be in partition 2
4. Ensure that the network is unhealthy after partition
5. Heal the partition and wait for all nodes to get back in sync

This test demonstrate Network Partitioning Testing Behavior of Kurtosis
*/

const (
	logLevel = logrus.InfoLevel

	enclaveId             = "cassandra-network-partitioning-0"
	isPartitioningEnabled = true

	cassandraStarlarkPackage = "github.com/kurtosis-tech/cassandra-package"

	// number of nodes to spin up, should be greater than or equal to 3
	numNodes = 3

	firstPartition  = "subnetwork0"
	secondPartition = "subnetwork1"

	defaultParallelism = 4

	noSerializedParams = ""
	noDryRun           = false

	updateServiceStarlarkTemplate = `plan.update_service(service_name = "%s", config = UpdateServiceConfig(subnetwork = "%s"))`
	headerStarlarkTemplate        = `def run(plan):`
)

func TestCassandraNetworkPartitioning(t *testing.T) {

	allowConnectionStarlark := fmt.Sprintf(`def run(plan):
	plan.set_connection(("%s", "%s"), kurtosis.connection.ALLOWED)`, firstPartition, secondPartition)

	blockConnectionStarlark := fmt.Sprintf(`def run(plan):
	plan.set_connection(("%s", "%s"), kurtosis.connection.BLOCKED)`, firstPartition, secondPartition)

	logrus.SetLevel(logLevel)
	packageParams := fmt.Sprintf("{\"num_nodes\": %d}", numNodes)

	ctx, cancelCtxFunc := context.WithCancel(context.Background())
	defer cancelCtxFunc()

	logrus.Info("------------ CONNECTING TO KURTOSIS ENGINE ---------------")
	kurtosisCtx, err := kurtosis_context.NewKurtosisContextFromLocalEngine()
	require.NoError(t, err, "An error occurred connecting to the Kurtosis engine")

	enclaveCtx, err := kurtosisCtx.CreateEnclave(ctx, enclaveId, isPartitioningEnabled)
	require.NoError(t, err, "An error occurred creating the enclave")
	defer kurtosisCtx.DestroyEnclave(ctx, enclaveId)

	logrus.Info("------------ EXECUTING PACKAGE ---------------")
	starlarkRunResult, err := enclaveCtx.RunStarlarkRemotePackageBlocking(ctx, cassandraStarlarkPackage, packageParams, false, defaultParallelism)
	require.NoError(t, err, "An error executing loading the Cassandra package")
	require.Nil(t, starlarkRunResult.InterpretationError)
	require.Empty(t, starlarkRunResult.ValidationErrors)
	require.Nil(t, starlarkRunResult.ExecutionError)

	cassandraNodeIds, err := getCassandraNodeIds(enclaveCtx)
	require.NoError(t, err, "An error occurred while trying to get cassandra node ids")
	require.Len(t, cassandraNodeIds, numNodes)

	starlarkRunResult, err = updateServicesWithPartitions(ctx, enclaveCtx, cassandraNodeIds)
	require.NoError(t, err, "An error occurred while executing Starlark to update service with partitions")
	require.Nil(t, starlarkRunResult.InterpretationError)
	require.Empty(t, starlarkRunResult.ValidationErrors)
	require.Nil(t, starlarkRunResult.ExecutionError)

	logrus.Info("------------ STARTING TEST CASE ---------------")
	logrus.Info("Verifying that all nodes are up by measuring both the first node and the last node")
	cassandraNodeInFirstPartition := cassandraNodeIds[0]
	cassandraNodeInSecondPartition := cassandraNodeIds[len(cassandraNodeIds)-1]

	upNodesMeasuredInFirstPartition, downNodesMeasuredInFirstPartition := getNumberOfUpAndDownNodes(cassandraNodeInFirstPartition, enclaveCtx, t)
	upNodesMeasuredInSecondPartition, downNodesMeasuredInSecondPartition := getNumberOfUpAndDownNodes(cassandraNodeInSecondPartition, enclaveCtx, t)

	require.Equal(t, upNodesMeasuredInFirstPartition, upNodesMeasuredInSecondPartition)
	require.Equal(t, numNodes, upNodesMeasuredInFirstPartition)

	require.Equal(t, downNodesMeasuredInSecondPartition, downNodesMeasuredInFirstPartition)
	require.Equal(t, 0, downNodesMeasuredInFirstPartition)

	logrus.Info("------------ INDUCING PARTITION ---------------")
	starlarkRunResult, err = enclaveCtx.RunStarlarkScriptBlocking(ctx, blockConnectionStarlark, noSerializedParams, noDryRun, defaultParallelism)
	require.NoError(t, err, "An error occurred while executing Stalark to partition network")
	require.Nil(t, starlarkRunResult.InterpretationError)
	require.Empty(t, starlarkRunResult.ValidationErrors)
	require.Nil(t, starlarkRunResult.ExecutionError)

	// give this some time before we check
	time.Sleep(15 * time.Second)

	logrus.Info("Verifying that the number of up and down nodes in different partitions are as expected")

	upNodesMeasuredInFirstPartition, downNodesMeasuredInFirstPartition = getNumberOfUpAndDownNodes(cassandraNodeInFirstPartition, enclaveCtx, t)
	upNodesMeasuredInSecondPartition, downNodesMeasuredInSecondPartition = getNumberOfUpAndDownNodes(cassandraNodeInSecondPartition, enclaveCtx, t)

	require.Equal(t, len(cassandraNodeIds)/2, upNodesMeasuredInFirstPartition)
	require.Equal(t, len(cassandraNodeIds)-len(cassandraNodeIds)/2, upNodesMeasuredInSecondPartition)

	require.Equal(t, len(cassandraNodeIds)/2, downNodesMeasuredInSecondPartition)
	require.Equal(t, len(cassandraNodeIds)-len(cassandraNodeIds)/2, downNodesMeasuredInFirstPartition)

	logrus.Info("------------ HEALING PARTITION ---------------")
	starlarkRunResult, err = enclaveCtx.RunStarlarkScriptBlocking(ctx, allowConnectionStarlark, noSerializedParams, noDryRun, defaultParallelism)
	require.NoError(t, err, "An error occurred while executing Stalark to update services to partition")
	require.Nil(t, starlarkRunResult.InterpretationError)
	require.Empty(t, starlarkRunResult.ValidationErrors)
	require.Nil(t, starlarkRunResult.ExecutionError)

	logrus.Info("------------ PARTITION HEALED ---------------")
	logrus.Info("Verifying that all nodes are up by measuring both the first node and the last node")

	// give this some time before we check
	time.Sleep(15 * time.Second)

	upNodesMeasuredInFirstPartition, downNodesMeasuredInFirstPartition = getNumberOfUpAndDownNodes(cassandraNodeInFirstPartition, enclaveCtx, t)
	upNodesMeasuredInSecondPartition, downNodesMeasuredInSecondPartition = getNumberOfUpAndDownNodes(cassandraNodeInSecondPartition, enclaveCtx, t)

	require.Equal(t, upNodesMeasuredInFirstPartition, upNodesMeasuredInSecondPartition)
	require.Equal(t, numNodes, upNodesMeasuredInFirstPartition)

	require.Equal(t, downNodesMeasuredInSecondPartition, downNodesMeasuredInFirstPartition)
	require.Equal(t, 0, downNodesMeasuredInFirstPartition)

}

func updateServicesWithPartitions(ctx context.Context, enclaveCtx *enclaves.EnclaveContext, cassandraNodeIds []services.ServiceName) (*enclaves.StarlarkRunResult, error) {
	commands := []string{headerStarlarkTemplate}
	for _, nodeIdForFirstPartition := range cassandraNodeIds[:len(cassandraNodeIds)/2] {
		commands = append(commands, "\t"+fmt.Sprintf(updateServiceStarlarkTemplate, nodeIdForFirstPartition, firstPartition))
	}
	for _, nodeIdForSecondPartition := range cassandraNodeIds[len(cassandraNodeIds)/2:] {
		commands = append(commands, "\t"+fmt.Sprintf(updateServiceStarlarkTemplate, nodeIdForSecondPartition, secondPartition))
	}
	fullStarlarkScript := strings.Join(commands, "\n")
	return enclaveCtx.RunStarlarkScriptBlocking(ctx, fullStarlarkScript, noSerializedParams, noDryRun, defaultParallelism)
}

func getCassandraNodeIds(
	enclaveCtx *enclaves.EnclaveContext,
) (
	[]services.ServiceName,
	error,
) {
	servicesInEnclave, err := enclaveCtx.GetServices()
	if err != nil {
		return nil, stacktrace.Propagate(err, "An error occurred while getting services within the enclave")
	}
	var result []services.ServiceName
	for serviceName := range servicesInEnclave {
		result = append(result, serviceName)
	}

	sort.Slice(result, func(i, j int) bool {
		return result[i] < result[j]
	})

	return result, nil
}

func getNumberOfUpAndDownNodes(cassandraNodeToCheck services.ServiceName, enclaveContext *enclaves.EnclaveContext, t *testing.T) (int, int) {
	serviceContext, err := enclaveContext.GetServiceContext(string(cassandraNodeToCheck))
	require.Nil(t, err)

	code, downNodesStr, err := serviceContext.ExecCommand([]string{"/bin/sh", "-c", "nodetool status | grep DN | wc -l | tr -d '\n'"})
	require.Nil(t, err)
	require.Zero(t, code)

	code, upNodesStr, err := serviceContext.ExecCommand([]string{"/bin/sh", "-c", "nodetool status | grep UN | wc -l | tr -d '\n'"})
	require.Nil(t, err)
	require.Zero(t, code)

	downNodes, err := strconv.Atoi(downNodesStr)
	require.Nil(t, err, "An error occurred converting '%v' to integer", downNodesStr)

	upNodes, err := strconv.Atoi(upNodesStr)
	require.Nil(t, err, "An error occurred converting '%v' to integer", upNodesStr)

	return upNodes, downNodes
}
