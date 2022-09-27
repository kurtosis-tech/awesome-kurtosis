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

	node0Id              = "el-client-0"
	node1Id              = "el-client-1"
	node2Id              = "el-client-2"

	rpcPortId = "rpc"

	retriesAttempts = 20
	retriesSleepDuration = 10 * time.Millisecond
)

var (
	unblockedPartitionConnection = enclaves.NewUnblockedPartitionConnection()
	blockedPartitionConnection   = enclaves.NewBlockedPartitionConnection()

	idsToQuery = []services.ServiceID{
		node0Id,
		node1Id,
		node2Id,
	}

	isTestInExecution bool
)

func TestNetworkPartitioning(t *testing.T) {
	isTestInExecution = true

	ctx := context.Background()

	kurtosisCtx, err := kurtosis_context.NewKurtosisContextFromLocalEngine()
	require.NoError(t, err, "An error occurred connecting to the Kurtosis engine")

	enclaveId := enclaves.EnclaveID(fmt.Sprintf(
		"%v-%v",
		testName, time.Now().Unix(),
	))
	enclaveCtx, err := kurtosisCtx.CreateEnclave(ctx, enclaveId, isPartitioningEnabled)
	require.NoError(t, err, "An error occurred creating the enclave")
	defer kurtosisCtx.StopEnclave(ctx, enclaveId)

	ethModuleCtx, err := enclaveCtx.LoadModule(ethModuleId, ethModuleImage, "{}")
	require.NoError(t, err, "An error occurred loading the ETH module")
	_, err = ethModuleCtx.Execute(moduleParams)
	require.NoError(t, err, "An error occurred executing the ETH module")

	nodeClientsByServiceIds, err := getNodeClientsByServiceID(enclaveCtx, idsToQuery)
	require.NoError(t, err, "An error occurred when trying to get the node clients for services with IDs '%+v'", idsToQuery)

	stopPrintingFunc, err := printNodeInfoUntilStopped(
		ctx,
		nodeClientsByServiceIds,
	)
	require.NoError(t, err, "An error occurred launching the node info printer thread")
	defer stopPrintingFunc()

	fmt.Println("------------ CHECKING IF ALL NODES ARE SYNC BEFORE THE PARTITION ---------------")
	syncedBlockNumber, err := waitUntilAllNodesGetSyncedBeforeInducingThePartition(ctx, idsToQuery, nodeClientsByServiceIds)
	require.NoError(t, err, "An error occurred waiting until all nodes get synced before inducing the partition")
	fmt.Println(fmt.Sprintf("--- ALL NODES SYNCED AT BLOCK NUMBER %v ---", syncedBlockNumber))
	fmt.Println("----------- VERIFIED THAT ALL NODES ARE SYNC BEFORE THE PARTITION --------------")

	fmt.Println("------------ INDUCING PARTITION ---------------")
	partitionNetwork(t, enclaveCtx)

	fmt.Println("------------ CHECKING FOR PARTITION BLOCKS DIVERGE ---------------")
	node0Client := nodeClientsByServiceIds[node0Id]
	node2Client := nodeClientsByServiceIds[node2Id]
	err = waitUntilNode0AndNode2DivergeBlockNumbers(ctx, node0Client, node2Client, syncedBlockNumber)
	require.NoError(t, err, "An error occurred waiting until de partition blocks diverge")
	fmt.Println("------------ VERIFIED THAT PARTITIONS BLOCKS DIVERGE ---------------")

	fmt.Println("------------ HEALING PARTITION ---------------")
	healNetwork(t, enclaveCtx)
	fmt.Println("------------ PARTITION HEALED ---------------")
	fmt.Println("------------ CHECKING IF ALL NODES ARE SYNC AFTER HEALING THE PARTITION ---------------")
	syncedBlockNumber, err = waitUntilAllNodesGetSyncedBeforeInducingThePartition(ctx, idsToQuery, nodeClientsByServiceIds)
	require.NoError(t, err, "An error occurred waiting until all nodes get synced after inducing the partition")
	fmt.Println(fmt.Sprintf("--- ALL NODES SYNCED AT BLOCK NUMBER %v ---", syncedBlockNumber))
	fmt.Println("----------- VERIFIED THAT ALL NODES ARE SYNC AFTER HEALING THE PARTITION --------------")

	isTestInExecution = false
}

func partitionNetwork(t *testing.T, enclaveCtx *enclaves.EnclaveContext) {
	partitionedNetworkServices := map[enclaves.PartitionID]map[services.ServiceID]bool{
		firstPartition: {
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

func getNodeClientsByServiceID(
	enclaveCtx *enclaves.EnclaveContext,
	serviceIds []services.ServiceID,
) (
	resultNodeClientsByServiceId map[services.ServiceID]*ethclient.Client,
	resultErr error,
) {
	nodeClientsByServiceIds := map[services.ServiceID]*ethclient.Client{}
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

		nodeClientsByServiceIds[serviceId] = client
	}
	return nodeClientsByServiceIds, nil
}

func printNodeInfoUntilStopped(
	ctx context.Context,
	nodeClientsByServiceIds map[services.ServiceID]*ethclient.Client,
) (func(), error) {

	printingStopChan := make(chan struct{})

	go func() {
		for true {
			select {
			case <-time.Tick(1 * time.Second):
				for serviceId, client := range nodeClientsByServiceIds {
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

func getMostRecentNodeBlockWithRetries(
	ctx context.Context,
	serviceId services.ServiceID,
	client *ethclient.Client,
	attempts int,
	sleep time.Duration,
) (*types.Block, error) {

	var resultBlock *types.Block
	var resultErr error

	blockNumberUint64, err := client.BlockNumber(ctx)
	if err != nil {
		resultErr = stacktrace.Propagate(err, "%-25sAn error occurred getting the block number", serviceId)
	}

	if resultErr == nil {
		blockNumberBigint := new(big.Int).SetUint64(blockNumberUint64)
		resultBlock, err = client.BlockByNumber(ctx, blockNumberBigint)
		if err != nil {
			resultErr = stacktrace.Propagate(err, "%-25sAn error occurred getting the latest block", serviceId)
		}
		if resultBlock == nil {
			resultErr = stacktrace.NewError("Something unexpected happened, block mustn't be nil; this is an error in the Geth client")
		}
	}

	if resultErr != nil {
		//Sometimes the client do not find the block, so we do retries
		if attempts--; attempts > 0 {
			time.Sleep(sleep)
			return getMostRecentNodeBlockWithRetries(ctx, serviceId, client, attempts, sleep)
		}
	}

	return resultBlock, resultErr
}

func printNodeInfo(ctx context.Context, serviceId services.ServiceID, client *ethclient.Client) {
	block, err := getMostRecentNodeBlockWithRetries(ctx, serviceId, client, retriesAttempts, retriesSleepDuration)
	if err != nil {
		if isTestInExecution {
			fmt.Println(fmt.Sprintf("%-25sAn error occurred getting the most recent block, err:\n%v", serviceId, err.Error()))
		}
		return
	}

	hexStr := block.Hash().Hex()

	fmt.Println(fmt.Sprintf("%-25sblock number: %v, block hash: %v", serviceId, block.Number(), hexStr))
}

func getMostRecentBlockAndStoreIt(
	ctx context.Context,
	serviceId services.ServiceID,
	serviceClient *ethclient.Client,
	nodeBlocksByServiceIds *sync.Map,
) error {
	block, err := getMostRecentNodeBlockWithRetries(ctx, serviceId, serviceClient, retriesAttempts, retriesSleepDuration)
	if err != nil {
		return stacktrace.Propagate(err, "An error occurred getting the most recent node block for service '%v'", serviceId)
	}

	nodeBlocksByServiceIds.Store(serviceId, block)

	return nil
}

func waitUntilAllNodesGetSyncedBeforeInducingThePartition(
	ctx context.Context,
	serviceIds []services.ServiceID,
	nodeClientsByServiceIds map[services.ServiceID]*ethclient.Client,
) (uint64, error) {
	var wg sync.WaitGroup
	nodeBlocksByServiceIds := &sync.Map{}
	errorChan := make(chan error, 1)
	defer close(errorChan)

	for true {
		select {
		case <-time.Tick(1 * time.Second):
			for _, serviceId := range serviceIds {
				wg.Add(1)
				nodeServiceId := serviceId
				nodeClient := nodeClientsByServiceIds[serviceId]
				go func() {
					defer wg.Done()

					if err := getMostRecentBlockAndStoreIt(ctx, nodeServiceId, nodeClient, nodeBlocksByServiceIds); err != nil {
						errorChan <- stacktrace.Propagate(err, "An error occurred getting the most recent node block and storing it for service '%v'", nodeServiceId)
					}
				}()
			}
			wg.Wait()

			var previousNodeBlockHash string
			var syncedBlockNumber uint64

			areAllEqual := true

			for _, serviceId := range serviceIds {

				uncastedNodeBlock, ok := nodeBlocksByServiceIds.LoadAndDelete(serviceId)
				if !ok {
					errorChan <- stacktrace.NewError("An error occurred loading the node's block for service with ID '%v'", serviceId)
					break
				}
				nodeBlock := uncastedNodeBlock.(*types.Block)
				nodeBlockHash := nodeBlock.Hash().Hex()

				if previousNodeBlockHash != "" && previousNodeBlockHash != nodeBlockHash {
					areAllEqual = false
					break
				}

				previousNodeBlockHash = nodeBlockHash
				syncedBlockNumber = nodeBlock.NumberU64()
			}

			if areAllEqual {
				return syncedBlockNumber, nil
			}

		case err := <-errorChan:
			if err != nil {
				return 0, stacktrace.Propagate(err, "An error occurred checking for synced nodes")
			}
			return 0, stacktrace.NewError("Something unexpected happened, a new value was received from the error channel but it's nil")
		}
	}

	return 0, nil
}

func waitUntilNode0AndNode2DivergeBlockNumbers(
	ctx context.Context,
	node0Client *ethclient.Client,
	node2Client *ethclient.Client,
	previousSyncedBlockNumber uint64,
) error {

	node0BlockNumber, node0BlockHash, err := getNextNode0BlockNumberAndHash(ctx, node0Client, node2Client, previousSyncedBlockNumber)
	if err != nil {
		return stacktrace.Propagate(err, "An error occurred getting the next node0 block number")
	}

	for true {
		select {
			case <-time.Tick(1 * time.Second):
				mostRecentNode2Block, err := getMostRecentNodeBlockWithRetries(ctx, node2Id, node2Client, retriesAttempts, retriesSleepDuration)
				if err != nil {
					return stacktrace.Propagate(err, "An error occurred waiting for node2 block number")
				}

				node2BlockNumber := mostRecentNode2Block.NumberU64()
				node2BlockHash :=  mostRecentNode2Block.Hash().Hex()

				fmt.Println(fmt.Sprintf("Node0 number '%v' and hash '%v', Node2 number '%v' and hash '%v'", node0BlockNumber, node0BlockHash, node2BlockNumber, node2BlockHash))

				if node0BlockNumber == node2BlockNumber && node0BlockHash == node2BlockHash {
					return stacktrace.NewError("Something unexpected happened, the generate node block hash, between nodes in different network partitions and after the partition, shouldn't be equal")
				}

				//Diverge assertion
				if node0BlockNumber == node2BlockNumber && node0BlockHash != node2BlockHash {
					return nil
				}
		}
	}

	return nil
}

func getNextNode0BlockNumberAndHash(
	ctx context.Context,
	node0Client *ethclient.Client,
	node2Client *ethclient.Client,
	previousSyncedBlockNumber uint64,
) (uint64, string, error){

	var wg sync.WaitGroup
	ethNodeBlocksByServiceId := &sync.Map{}
	errorChanForCheckingNode0 := make(chan error, 1)
	defer close(errorChanForCheckingNode0)

	for true {
		select {
		case <-time.Tick(1 * time.Second):
			wg.Add(2)

			//node0
			go func() {
				defer wg.Done()
				block, err := getMostRecentNodeBlockWithRetries(ctx, node0Id, node0Client, retriesAttempts, retriesSleepDuration)
				if err != nil {
					errorChanForCheckingNode0 <- stacktrace.Propagate(err, "An error occurred getting the mos recent node bloc for service '%v'", node0Id)
				}
				ethNodeBlocksByServiceId.Store(node0Id, block)

			}()

			//node2
			go func() {
				defer wg.Done()
				block, err := getMostRecentNodeBlockWithRetries(ctx, node2Id, node2Client, retriesAttempts, retriesSleepDuration)
				if err != nil {
					errorChanForCheckingNode0 <- stacktrace.Propagate(err, "An error occurred getting the mos recent node bloc for service '%v'", node2Id)
				}
				ethNodeBlocksByServiceId.Store(node2Id, block)
			}()

			wg.Wait()

			uncastedNode0Block, ok := ethNodeBlocksByServiceId.LoadAndDelete(node0Id)
			if !ok {
				return 0, "", stacktrace.NewError("An error occurred loading the node's block for service with ID '%v', the value for ley '%v' was no loaded", node0Id, node0Id)
			}
			node0Block := uncastedNode0Block.(*types.Block)

			uncastedNode2Block, ok := ethNodeBlocksByServiceId.LoadAndDelete(node2Id)
			if !ok {
				return 0, "", stacktrace.NewError("An error occurred loading the node's block for service with ID '%v', the value for ley '%v' was no loaded", node2Id, node2Id)
			}
			node2Block := uncastedNode2Block.(*types.Block)

			//We are waiting for nex node0 block number after the partition
			if node0Block.NumberU64() <= previousSyncedBlockNumber {
				continue
			}

			if node0Block.NumberU64() > node2Block.NumberU64() {
				return node0Block.NumberU64(), node0Block.Hash().Hex(), nil
			}
		case err := <-errorChanForCheckingNode0:

			if err != nil {
				return 0, "", stacktrace.Propagate(err, "An error occurred checking for next partition1 block number and hash")
			}
			return 0, "", stacktrace.NewError("Something unexpected happened, a new value was received from the error channel but it's nil")
		}
	}
	return 0, "", nil
}