package main

import (
	"context"
	"fmt"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/kurtosis-tech/kurtosis-core-api-lib/api/golang/lib/enclaves"
	"github.com/kurtosis-tech/kurtosis-core-api-lib/api/golang/lib/services"
	"github.com/kurtosis-tech/kurtosis-engine-api-lib/api/golang/lib/kurtosis_context"
	"github.com/kurtosis-tech/stacktrace"
	"github.com/stretchr/testify/require"
	"math/big"
	"testing"
	"time"
)

const (
	testName              = "go-network-partitioning"
	isPartitioningEnabled = true

	ethModuleId    = "eth-module"
	ethModuleImage = "kurtosistech/ethereum-kurtosis-module"
	moduleParams   = "{}"

	firstPartition  = "partition0"
	secondPartition = "partition1"

	node0Id = "bootnode"
	node1Id = "ethereum-node-1"
	node2Id = "ethereum-node-2"

	rpcPortId = "rpc"
)

var (
	unblockedPartitionConnection = enclaves.NewUnblockedPartitionConnection()
	blockedPartitionConnection   = enclaves.NewBlockedPartitionConnection()

	idsToQuery = []services.ServiceID{
		node0Id,
		node1Id,
		node2Id,
	}
)

func TestNetworkPartitioning(t *testing.T) {
	ctx := context.Background()

	kurtosisCtx, err := kurtosis_context.NewKurtosisContextFromLocalEngine()
	require.NoError(t, err, "An error occurred connecting to the Kurtosis engine")

	enclaveId := enclaves.EnclaveID(fmt.Sprintf(
		"%v-%v",
		testName, time.Now().Unix(),
	))
	enclaveCtx, err := kurtosisCtx.CreateEnclave(ctx, enclaveId, isPartitioningEnabled)
	require.NoError(t, err, "An error occurred creating the enclave")
	// defer kurtosisCtx.StopEnclave(ctx, enclaveId)

	ethModuleCtx, err := enclaveCtx.LoadModule(ethModuleId, ethModuleImage, "{}")
	require.NoError(t, err, "An error occurred loading the ETH module")
	_, err = ethModuleCtx.Execute(moduleParams)
	require.NoError(t, err, "An error occurred executing the ETH module")

	stopPrintingFunc, err := printNodeInfoUntilStopped(
		ctx,
		enclaveCtx,
		idsToQuery,
	)
	require.NoError(t, err, "An error occurred launching the node info printer thread")
	defer stopPrintingFunc()

	time.Sleep(60 * time.Second)

	fmt.Println("------------ INDUCING PARTITION ---------------")
	partitionNetwork(t, enclaveCtx)

	time.Sleep(30 * time.Second)

	fmt.Println("------------ HEALING PARTITION ---------------")
	healNetwork(t, enclaveCtx)

	time.Sleep(60 * time.Second)
}

func partitionNetwork(t *testing.T, enclaveCtx *enclaves.EnclaveContext) {
	partitionedNetworkServices := map[enclaves.PartitionID]map[services.ServiceID]bool{
		firstPartition: {
			node0Id: true,
			node1Id: true,
		},
		secondPartition: {
			node2Id: true,
		},
	}
	partitionedNetworkConnections := map[enclaves.PartitionID]map[enclaves.PartitionID]enclaves.PartitionConnection{
		firstPartition: {
			secondPartition: blockedPartitionConnection,
		},
	}

	err := enclaveCtx.RepartitionNetwork(
		partitionedNetworkServices,
		partitionedNetworkConnections,
		blockedPartitionConnection,
	)
	require.NoError(t, err, "An error occurred repartitioning the network")
}

func healNetwork(t *testing.T, enclaveCtx *enclaves.EnclaveContext) {
	healedNetworkServices := map[enclaves.PartitionID]map[services.ServiceID]bool{
		"pangea": {
			node0Id: true,
			node1Id: true,
			node2Id: true,
		},
	}
	healedNetworkConnections := map[enclaves.PartitionID]map[enclaves.PartitionID]enclaves.PartitionConnection{}

	err := enclaveCtx.RepartitionNetwork(
		healedNetworkServices,
		healedNetworkConnections,
		unblockedPartitionConnection,
	)
	require.NoError(t, err, "An error occurred healing the network partition")
}

func printNodeInfoUntilStopped(
	ctx context.Context,
	enclaveCtx *enclaves.EnclaveContext,
	serviceIds []services.ServiceID,
) (func(), error) {
	clients := []*ethclient.Client{}
	for _, serviceId := range serviceIds {
		serviceCtx, err := enclaveCtx.GetServiceContext(serviceId)
		if err != nil {
			return nil, stacktrace.Propagate(err, "A fatal error occurred getting context for service '%v'", serviceId)
		}

		rpcPort, found := serviceCtx.GetPublicPorts()[rpcPortId]
		if !found {
			return nil, stacktrace.NewError("Service '%v' doesn't have expected RPC port with ID '%v'", serviceId, rpcPortId)
		}

		url := fmt.Sprintf(
			"http://%v:%v",
			serviceCtx.GetMaybePublicIPAddress(),
			rpcPort.GetNumber(),
		)
		client, err := ethclient.Dial(url)
		if err != nil {
			return nil, stacktrace.Propagate(err, "A fatal error occurred creating the ETH client for service '%v'", serviceId)
		}

		clients = append(clients, client)
	}

	printingStopChan := make(chan struct{})

	go func() {
		for true {
			select {
			case <-time.Tick(1 * time.Second):
				for idx, client := range clients {
					serviceId := serviceIds[idx]
					printNodeInfo(ctx, serviceId, client)
				}
			case <-printingStopChan:
				break
			}
		}
	}()

	stopFunc := func() {
		printingStopChan <- struct{}{}
	}

	return stopFunc, nil
}

func printNodeInfo(ctx context.Context, serviceId services.ServiceID, client *ethclient.Client) {
	blockNumberUint64, err := client.BlockNumber(ctx)
	if err != nil {
		fmt.Println(fmt.Sprintf("%-25sAn error occurred getting the block number", serviceId))
		return
	}

	blockNumberBigint := new(big.Int).SetUint64(blockNumberUint64)
	block, err := client.BlockByNumber(ctx, blockNumberBigint)
	if err != nil {
		fmt.Println(fmt.Sprintf("%-25sAn error occurred getting the latest block", serviceId))
		return
	}
	hexStr := block.Hash().Hex()

	fmt.Println(fmt.Sprintf("%-25sblock number: %v, block hash: %v", serviceId, block.Number(), hexStr))
}
