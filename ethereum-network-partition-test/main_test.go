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
	//defer kurtosisCtx.StopEnclave(ctx, enclaveId)

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

	fmt.Println("------------ CHECKING IF ALL NODES ARE SYNC BEFORE THE PARTITION ---------------")
	syncedBlockNumber, err := waitUntilAllNodesGetSyncedBeforeInducingThePartition(ctx, idsToQuery, nodeClientsByServiceIds)
	require.NoError(t, err, "An error occurred waiting until all nodes get synced before inducing the partition")
	fmt.Println(fmt.Sprintf("--- ALL NODES SYNCED AT BLOCK NUMBER %v ---", syncedBlockNumber))
	fmt.Println("----------- VERIFIED THAT ALL NODES ARE SYNC BEFORE THE PARTITION --------------")

	fmt.Println("------------ INDUCING PARTITION ---------------")
	partitionNetwork(t, enclaveCtx)

	partitions := []enclaves.PartitionID{
		firstPartition,
		secondPartition,
	}
	nodeClientsByPartitionIds := []ethclient.Client{
		nodeClientsByServiceIds[0],
		nodeClientsByServiceIds[2],
	}

	fmt.Println("------------ CHECKING FOR PARTITION BLOCKS DIVERGE ---------------")
	err = waitUntilPartitionsDivergeBlockNumbers(ctx, partitions, nodeClientsByPartitionIds, nodeClientsByServiceIds[2], syncedBlockNumber)
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

func getNodeClientsByServiceIds(
	enclaveCtx *enclaves.EnclaveContext,
	serviceIds []services.ServiceID,
) (
	resultClientsByServiceId []ethclient.Client,
	resultErr error,
) {
	nodeClientsByServiceIds := []ethclient.Client{}
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

		nodeClientsByServiceIds = append(nodeClientsByServiceIds, *client)
	}
	return nodeClientsByServiceIds, nil
}

func printNodeInfoUntilStopped(
	ctx context.Context,
	serviceIds []services.ServiceID,
	nodeClientsByServiceIds []ethclient.Client,
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
	resourceID string,
	client ethclient.Client,
) (*types.Block, error) {
	blockNumberUint64, err := client.BlockNumber(ctx)
	if err != nil {
		return nil, stacktrace.Propagate(err, "%-25sAn error occurred getting the block number", resourceID)
	}

	blockNumberBigint := new(big.Int).SetUint64(blockNumberUint64)
	block, err := client.BlockByNumber(ctx, blockNumberBigint)
	if err != nil {
		return nil, stacktrace.Propagate(err, "%-25sAn error occurred getting the latest block", resourceID)
	}
	if block == nil {
		return nil, stacktrace.NewError("Something unexpected happened, block mustn't be nil; this is an error in the Geth client")
	}
	return block, nil
}

func printNodeInfo(ctx context.Context, serviceId services.ServiceID, client ethclient.Client) {
	block, err := getMostRecentNodeBlock(ctx, string(serviceId), client)
	if err != nil {
		fmt.Println(fmt.Sprintf("%-25sAn error occurred getting the most recent block, err:\n%v", serviceId, err.Error()))
		return
	}

	hexStr := block.Hash().Hex()

	fmt.Println(fmt.Sprintf("%-25sblock number: %v, block hash: %v", serviceId, block.Number(), hexStr))
}


//TODO close the channels ??
func waitUntilAllNodesGetSyncedBeforeInducingThePartition(
	ctx context.Context,
	serviceIds []services.ServiceID,
	nodeClientsByServiceIds []ethclient.Client,
) (uint64, error) {
	var wg sync.WaitGroup
	result := sync.Map{}
	errorChan := make(chan error)

	for true {
		select {
		case <-time.Tick(1 * time.Second):
			for idx, client := range nodeClientsByServiceIds {
				wg.Add(1)
				serviceClient := client
				serviceId := serviceIds[idx]
				go func() {
					defer wg.Done()
					block, err := getMostRecentNodeBlock(ctx, string(serviceId), serviceClient)
					if err != nil {
						errorChan <- err //I think that we can change this for a return statement
					}
					result.Store(serviceId, block)
					blockHash := block.Hash().Hex()
					fmt.Println(fmt.Sprintf("Checking sync - serviceId '%v' block number '%v' - block hash '%v'", serviceId, block.Number(), blockHash))
				}()

			}
			wg.Wait()

			var previousNodeBlockHash string
			var previosNodeBlockNumber *big.Int
			var syncedBlockNumber uint64

			areAllEqual := true
			for _, serviceId := range serviceIds {
				uncastedNodeBlock, ok := result.LoadAndDelete(serviceId)
				if !ok {
					errorChan <- stacktrace.NewError("An error occurred loading the nodeBlock for service with ID '%v'", serviceId)
				}
				nodeBlock := uncastedNodeBlock.(*types.Block)
				nodeBlockNumber := nodeBlock.Number()

				nodeBlockHash := nodeBlock.Hash().Hex()
				fmt.Println(fmt.Sprintf("Service ID %v - Previous block number '%v' and hash '%v', node block number '%v' and hash '%v'", serviceId, previosNodeBlockNumber, previousNodeBlockHash, nodeBlockNumber, nodeBlockHash))
				if previousNodeBlockHash != "" && previousNodeBlockHash != nodeBlockHash {
					fmt.Println(fmt.Sprintf("No equal - Previous blo '%v', node blo '%v'", previousNodeBlockHash, nodeBlockHash))
					areAllEqual = false
					break
				} else {
					fmt.Println(fmt.Sprintf("Equal - Previous blo '%v', node blo '%v'", previousNodeBlockHash, nodeBlockHash))
				}
				previosNodeBlockNumber = nodeBlockNumber
				previousNodeBlockHash = nodeBlockHash
				syncedBlockNumber = nodeBlock.NumberU64()
			}

			if areAllEqual {
				fmt.Println("--ALL ARE EQUALS!!--")
				return syncedBlockNumber, nil
			} else {
				fmt.Println("--ALL AREN'T EQUALS!!--")
			}

		case err := <-errorChan:  //TODO checks if it works on this way
			return 0, stacktrace.Propagate(err, "An error occurred checking for synced nodes") //I think we can remove this
		}
	}

	return 0, nil
}

func waitUntilPartitionsDivergeBlockNumbers(
	ctx context.Context,
	partitionIDs []enclaves.PartitionID,
	nodeClientsByPartitionIds []ethclient.Client,
	partition2Client ethclient.Client,
	previousSyncedBlockNumber uint64,
) error {

	partition1BlockNumber, partition1BlockHash, err := getNextPartition1BlockNumberAndHash(ctx, partitionIDs, nodeClientsByPartitionIds, previousSyncedBlockNumber)
	if err != nil {
		return stacktrace.Propagate(err, "An error occurred getting the next partition 1 block number")
	}

	for true {
		select {
			case <-time.Tick(1 * time.Second):
				block, err := getMostRecentNodeBlock(ctx, "partition2", partition2Client)
				if err != nil {
					return stacktrace.Propagate(err, "An error occurred waiting for partitin2 block number")
				}

				partition2BlockNumber := block.NumberU64()
				partition2BlockHash :=  block.Hash().Hex()

				fmt.Println(fmt.Sprintf("Partition1 number '%v' and hash '%v', Partition2 number '%v' and hash '%v'", partition1BlockNumber, partition1BlockHash, partition2BlockNumber, partition2BlockHash))
				if partition2BlockNumber > partition1BlockNumber {
					return stacktrace.NewError("If this happen we are in troubles, we should change this")
				}

				if partition1BlockNumber == partition2BlockNumber && partition1BlockHash == partition2BlockHash {
					return stacktrace.NewError("This should never happen during a partition")
				}

				if partition1BlockNumber == partition2BlockNumber && partition1BlockHash != partition2BlockHash {
					return nil
				}
		}
	}

	return nil
}

func getNextPartition1BlockNumberAndHash(
	ctx context.Context,
	partitionIDs []enclaves.PartitionID,
	nodeClientsByPartitionIds []ethclient.Client,
	previousSyncedBlockNumber uint64,
) (uint64, string, error){

	var wg sync.WaitGroup
	result := sync.Map{}
	errorChan := make(chan error)

	for true {
		select {
		case <-time.Tick(1 * time.Second):
			for idx, client := range nodeClientsByPartitionIds {
				wg.Add(1)
				partitionClient := client
				partitionID := partitionIDs[idx]
				go func() {
					defer wg.Done()
					block, err := getMostRecentNodeBlock(ctx, string(partitionID), partitionClient)
					if err != nil {
						errorChan <- err
					}
					result.Store(partitionID, block)
					blockHash := block.Hash().Hex()
					fmt.Println(fmt.Sprintf("Checking sync - partitionID '%v' block number '%v' - block hash '%v'", partitionID, block.Number(), blockHash))
				}()

			}
			wg.Wait()

			uncastedPartition1NodeBlock, ok := result.LoadAndDelete(partitionIDs[0])
			if !ok {
				errorChan <- stacktrace.NewError("An error occurred loading the nodeBlock for partition with ID '%v'", partitionIDs[0])
			}
			partition1NodeBlock := uncastedPartition1NodeBlock.(*types.Block)

			uncastedPartition2NodeBlock, ok := result.LoadAndDelete(partitionIDs[1])
			if !ok {
				errorChan <- stacktrace.NewError("An error occurred loading the nodeBlock for partition with ID '%v'", partitionIDs[1])
			}
			partition2NodeBlock := uncastedPartition2NodeBlock.(*types.Block)

			if partition1NodeBlock.NumberU64() <= previousSyncedBlockNumber {
				continue
			}
			fmt.Println(fmt.Sprintf("Comparing partitiong blocks - partition1 '%v' partition2 '%v' ", partition1NodeBlock.NumberU64(), partition2NodeBlock.NumberU64()))
			if partition1NodeBlock.NumberU64() > partition2NodeBlock.NumberU64() {
				return partition1NodeBlock.NumberU64(), partition1NodeBlock.Hash().Hex(), nil
			}

		case err := <-errorChan:  //TODO checks if it works on this way
			return 0, "", stacktrace.Propagate(err, "An error occurred checking for synced nodes")
		}
	}
	return 0, "", nil
}