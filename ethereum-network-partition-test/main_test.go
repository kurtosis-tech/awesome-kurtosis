package main

import (
	"context"
	"fmt"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/kurtosis-tech/kurtosis-core-api-lib/api/golang/lib/enclaves"
	"github.com/kurtosis-tech/kurtosis-core-api-lib/api/golang/lib/services"
	"github.com/kurtosis-tech/kurtosis-engine-api-lib/api/golang/lib/kurtosis_context"
	"github.com/kurtosis-tech/stacktrace"
	"github.com/stretchr/testify/require"
	"math/big"
	"sync"
	"testing"
	"time"
)

/*
This test will start a three-node Ethereum network, partition it, and then heal the partition to demonstrate
Ethereum-forking behaviour in Kurtosis.
*/

const (
	testName              = "go-network-partitioning"
	isPartitioningEnabled = true

	ethModuleId    = "eth-module"
	ethModuleImage = "kurtosistech/eth2-merge-kurtosis-module:latest"
	moduleParams   = `{
	"executionLayerOnly": true,
	"participants": [
		{"elType":"geth","clType":"lodestar"},
		{"elType":"geth","clType":"lodestar"},
		{"elType":"geth","clType":"lodestar"}
	]
}`

	firstPartition  = "partition0"
	secondPartition = "partition1"

	transactionSpammerId = "transaction-spammer"
	node0Id              = "el-client-0"
	node1Id              = "el-client-1"
	node2Id              = "el-client-2"

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

	nodeClientsByServiceIds, err := getNodeClientsByServiceIds(enclaveCtx, idsToQuery)
	require.NoError(t, err, "An error occurred when trying to get the node clients for services with IDs '%+v'", idsToQuery)

	stopPrintingFunc, err := printNodeInfoUntilStopped(
		ctx,
		idsToQuery,
		nodeClientsByServiceIds,
	)
	require.NoError(t, err, "An error occurred launching the node info printer thread")
	defer stopPrintingFunc()

	time.Sleep(10 * time.Second)

	err = waitUntilAllNodesGetSyncedBeforeInducingThePartition(ctx, idsToQuery, nodeClientsByServiceIds)
	require.NoError(t, err, "An error occurred waiting until all nodes get synced before inducing the partition")


	fmt.Println("------------ INDUCING PARTITION ---------------")
	partitionNetwork(t, enclaveCtx)



	fmt.Println("------------ HEALING PARTITION ---------------")
	healNetwork(t, enclaveCtx)

	time.Sleep(2 * time.Minute)
}

func partitionNetwork(t *testing.T, enclaveCtx *enclaves.EnclaveContext) {
	partitionedNetworkServices := map[enclaves.PartitionID]map[services.ServiceID]bool{
		firstPartition: {
			transactionSpammerId: true,
			node0Id:              true,
			node1Id:              true,
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
			transactionSpammerId: true,
			node0Id:              true,
			node1Id:              true,
			node2Id:              true,
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

func getNodeClientsByServiceIds(
	enclaveCtx *enclaves.EnclaveContext,
	serviceIds []services.ServiceID,
) (
	resultClientsByServiceId []*ethclient.Client,
	resultErr error,
) {
	nodeClientsByServiceIds := []*ethclient.Client{}
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

		nodeClientsByServiceIds = append(nodeClientsByServiceIds, client)
	}
	return nodeClientsByServiceIds, nil
}

func printNodeInfoUntilStopped(
	ctx context.Context,
	serviceIds []services.ServiceID,
	nodeClientsByServiceIds []*ethclient.Client,
) (func(), error) {

	printingStopChan := make(chan struct{})

	go func() {
		for true {
			select {
			case <-time.Tick(1 * time.Second):
				for idx, client := range nodeClientsByServiceIds {
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

func getMostRecentNodeBlock(
	ctx context.Context,
	serviceId services.ServiceID,
	client *ethclient.Client,
) (*types.Block, error) {
	blockNumberUint64, err := client.BlockNumber(ctx)
	if err != nil {
		return nil, stacktrace.Propagate(err, "%-25sAn error occurred getting the block number", serviceId)
	}

	blockNumberBigint := new(big.Int).SetUint64(blockNumberUint64)
	block, err := client.BlockByNumber(ctx, blockNumberBigint)
	if err != nil {
		return nil, stacktrace.Propagate(err, "%-25sAn error occurred getting the latest block", serviceId)
	}
	if block == nil {
		return nil, stacktrace.NewError("Something unexpected happened, block mustn't be nil; this is an error in the Geth client")
	}
	return block, nil
}

func printNodeInfo(ctx context.Context, serviceId services.ServiceID, client *ethclient.Client) {
	block, err := getMostRecentNodeBlock(ctx, serviceId, client)
	if err != nil {
		fmt.Println(fmt.Sprintf("%-25sAn error occurred getting the most recent block, err:\n%v", serviceId, err.Error()))
	}

	hexStr := block.Hash().Hex()

	fmt.Println(fmt.Sprintf("%-25sblock number: %v, block hash: %v", serviceId, block.Number(), hexStr))
}

func waitUntilAllNodesGetSyncedBeforeInducingThePartition(
	ctx context.Context,
	serviceIds []services.ServiceID,
	nodeClientsByServiceIds []*ethclient.Client,
) error {
	var wg sync.WaitGroup
	result := sync.Map{}

	errorChan := make(chan error)
	for true {
		select {
		case <-time.Tick(1 * time.Millisecond):
			for idx, client := range nodeClientsByServiceIds {
				wg.Add(1)

				serviceId := serviceIds[idx]
				go func() {
					defer wg.Done()
					block, err := getMostRecentNodeBlock(ctx, serviceId, client)
					if err != nil {
						errorChan <- err
					}
					blockHash := block.Hash().Hex()
					result.Store(serviceId, blockHash)
					fmt.Println(fmt.Sprintf("Waiting until func serviceId '%v' - block hash '%v'", serviceId, blockHash))
				}()

			}
			wg.Wait()

			var previousNodeBlockHash string
			fmt.Println(fmt.Sprintf("Result '%v'", result))
			areAllEqual := true
			for _, serviceId := range serviceIds {
				uncastedNodeBlockHash, ok := result.LoadAndDelete(serviceId)
				if !ok {
					errorChan <- stacktrace.NewError("An error occurred loading the nodeBlock for service with ID '%v'", serviceId)
				}
				nodeBlockHash := uncastedNodeBlockHash.(string)
				fmt.Println(fmt.Sprintf("Service ID %v - Previous blo '%v', node blo '%v'", serviceId, previousNodeBlockHash, nodeBlockHash))
				if previousNodeBlockHash != nodeBlockHash {
					fmt.Println(fmt.Sprintf("No equal - Previous blo '%v', node blo '%v'", previousNodeBlockHash, nodeBlockHash))
					areAllEqual = false
				}else {
					fmt.Println(fmt.Sprintf("Equal - Previous blo '%v', node blo '%v'", previousNodeBlockHash, nodeBlockHash))
				}
				previousNodeBlockHash = nodeBlockHash
			}
			if areAllEqual {
				break
			}

		case err := <-errorChan:  //TODO checks if it works on this way
			return stacktrace.Propagate(err, "An error occurred checking for synced nodes")
		}
	}

	return nil
}
