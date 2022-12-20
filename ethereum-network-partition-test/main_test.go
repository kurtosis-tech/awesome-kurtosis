package main

import (
	"context"
	"fmt"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/kurtosis-tech/kurtosis-sdk/api/golang/core/lib/enclaves"
	"github.com/kurtosis-tech/kurtosis-sdk/api/golang/core/lib/services"
	"github.com/kurtosis-tech/kurtosis-sdk/api/golang/engine/lib/kurtosis_context"
	"github.com/kurtosis-tech/stacktrace"
	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/require"
	"math/big"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"
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

	enclaveId             = "ethereum-network-partitioning"
	isPartitioningEnabled = true

	nodeInfoPrefix = "NODES STATUS -- |"

	eth2StarlarkPackage = "github.com/kurtosis-tech/eth2-package"

	// must be something greater than 4 to have at least 2 nodes in each partition
	numParticipants = 4

	participantsPlaceholder = "{{participants_param}}"
	//participantParam        = `{"elType":"geth","elImage":"ethereum/client-go:v1.10.25","clType":"lodestar","clImage":"chainsafe/lodestar:v1.1.0"}`
	participantParam     = `{"el_client_type":"geth","el_client_image":"ethereum/client-go:v1.10.25","cl_client_type":"lighthouse","cl_client_image":"sigp/lighthouse:v3.1.2"}`
	moduleParamsTemplate = `{
	"launch_additional_services": false,
	"participants": [
		` + participantsPlaceholder + `
	]
}`

	// Before partitioning, test will wait for all nodes to be synced AND this block number to be reached (whichever
	// comes last)
	// This is handy to make sure everything works fine before test introduces the partition.
	// Set to 0 if you want the partition to happen as soon as possible
	minimumNumberOfBlocksToProduceBeforePartition = 2

	// Once the partition is enabled, number of blocks to wait in each partition before validating that it has diverged
	// Technically, divergence should happen on the very first block after partition is introduced, so `1` is a good
	// value here, but to slow down the test a bit it can be set to something > 1
	// With this set to 2, it means that if partition is introduced when all nodes are synced on block #3, it will
	// check divergence on block number 3 + 2 = 5 in each partition.
	numberOfBlockToProduceBeforeCheckingDivergence = 2

	// Once partitions are healed, test will wait for all node to be synced AND this number of blocks to be produced
	// in the most advances partition.
	// For example, with this set to 2, if healing happens when partition 1 is at block #10 and partition 2 at block
	// number 6, it will wait for all node to be synced and minimum block number to be 10 + 2 = 12.
	minimumNumberOfBlocksToProduceAfterHealing = 2

	firstPartition  = "partition0"
	secondPartition = "partition1"
	healedPartition = "pangea"

	elNodeIdTemplate          = "el-client-%d"
	clNodeBeaconIdTemplate    = "cl-client-%d-beacon"
	clNodeValidatorIdTemplate = "cl-client-%d-validator"

	rpcPortId = "rpc"

	retriesAttempts      = 20
	retriesSleepDuration = 10 * time.Millisecond

	newlineChar = "\n"
)

var (
	unblockedPartitionConnection = enclaves.NewUnblockedPartitionConnection()
	blockedPartitionConnection   = enclaves.NewBlockedPartitionConnection()

	nodeIds    = make([]int, numParticipants)
	idsToQuery = make([]services.ServiceID, numParticipants)

	isTestInExecution bool
)

func TestNetworkPartitioning(t *testing.T) {
	logrus.SetLevel(logLevel)
	isTestInExecution = true
	moduleParams := initNodeIdsAndRenderModuleParam()

	ctx := context.Background()

	logrus.Info("------------ CONNECTING TO KURTOSIS ENGINE ---------------")
	kurtosisCtx, err := kurtosis_context.NewKurtosisContextFromLocalEngine()
	require.NoError(t, err, "An error occurred connecting to the Kurtosis engine")

	enclaveCtx, err := kurtosisCtx.CreateEnclave(ctx, enclaveId, isPartitioningEnabled)
	require.NoError(t, err, "An error occurred creating the enclave")
	// we only stop the enclave instead of destroying it as this allows users  to debug  their enclave after the tests are run
	// we recommend using `DestroyEnclave` to destroy & clean up the enclave if you don't want remaining artifacts
	defer kurtosisCtx.StopEnclave(ctx, enclaveId)

	logrus.Info("------------ EXECUTING MODULE ---------------")
	starlarkRunResult, err := enclaveCtx.RunStarlarkRemotePackageBlocking(ctx, eth2StarlarkPackage, moduleParams, false)
	require.NoError(t, err, "An error executing loading the ETH module")
	require.Nil(t, starlarkRunResult.InterpretationError)
	require.Empty(t, starlarkRunResult.ValidationErrors)
	require.Nil(t, starlarkRunResult.ExecutionError)

	nodeClientsByServiceIds, err := getElNodeClientsByServiceID(enclaveCtx, idsToQuery)
	require.NoError(t, err, "An error occurred when trying to get the node clients for services with IDs '%+v'", idsToQuery)

	logrus.Info("------------ STARTING TEST CASE ---------------")
	stopPrintingFunc, err := printNodeInfoUntilStopped(
		ctx,
		nodeClientsByServiceIds,
	)
	require.NoError(t, err, "An error occurred launching the node info printer thread")
	defer stopPrintingFunc()

	logrus.Infof("------------ CHECKING ALL NODES ARE IN SYNC AT BLOCK '%d' ---------------", minimumNumberOfBlocksToProduceBeforePartition)
	syncedBlockNumber, err := waitUntilAllNodesGetSynced(ctx, idsToQuery, nodeClientsByServiceIds, minimumNumberOfBlocksToProduceBeforePartition)
	require.NoError(t, err, "An error occurred waiting until all nodes get synced before inducing the partition")
	logrus.Infof("------------ ALL NODES SYNCED AT BLOCK NUMBER '%v' ------------", syncedBlockNumber)
	printAllNodesInfo(ctx, nodeClientsByServiceIds)
	logrus.Info("------------ VERIFIED ALL NODES ARE IN SYNC BEFORE THE PARTITION ------------")

	logrus.Info("------------ INDUCING PARTITION ---------------")
	partitionNetwork(t, enclaveCtx)

	logrus.Infof("------------ CHECKING BLOCKS DIVERGE AT BLOCK NUMBER '%d' ---------------", syncedBlockNumber+numberOfBlockToProduceBeforeCheckingDivergence)
	// node 0 and node N will necessarily be in a different partition
	node0ServiceId := renderServiceId(elNodeIdTemplate, nodeIds[0])
	node0Client := nodeClientsByServiceIds[renderServiceId(elNodeIdTemplate, nodeIds[0])]
	nodeNServiceId := renderServiceId(elNodeIdTemplate, nodeIds[len(nodeIds)-1])
	nodeNClient := nodeClientsByServiceIds[nodeNServiceId]
	maxBlockNumberInPartitions, err := waitUntilNode0AndNodeNDivergeBlockNumbers(ctx, node0ServiceId, node0Client, nodeNServiceId, nodeNClient, syncedBlockNumber+numberOfBlockToProduceBeforeCheckingDivergence)
	require.NoError(t, err, "An error occurred waiting until the partition blocks diverge")
	logrus.Info("------------ VERIFIED THAT PARTITIONS BLOCKS DIVERGE ---------------")
	printAllNodesInfo(ctx, nodeClientsByServiceIds)

	logrus.Info("------------ HEALING PARTITION ---------------")
	healNetwork(t, enclaveCtx)
	logrus.Info("------------ PARTITION HEALED ---------------")
	logrus.Infof("------------ CHECKING ALL NODES ARE BACK IN SYNC AT BLOCK '%d' ---------------", maxBlockNumberInPartitions+minimumNumberOfBlocksToProduceAfterHealing)
	syncedBlockNumber, err = waitUntilAllNodesGetSynced(ctx, idsToQuery, nodeClientsByServiceIds, maxBlockNumberInPartitions+minimumNumberOfBlocksToProduceAfterHealing)
	require.NoError(t, err, "An error occurred waiting until all nodes get synced after inducing the partition")
	logrus.Infof("----------- ALL NODES SYNCED AT BLOCK NUMBER '%v' -----------", syncedBlockNumber)
	printAllNodesInfo(ctx, nodeClientsByServiceIds)
	logrus.Info("----------- VERIFIED THAT ALL NODES ARE IN SYNC AFTER HEALING THE PARTITION --------------")

	isTestInExecution = false
}

func initNodeIdsAndRenderModuleParam() string {
	participantParams := make([]string, numParticipants)
	for idx := 0; idx < numParticipants; idx++ {
		nodeIds[idx] = idx
		idsToQuery[idx] = renderServiceId(elNodeIdTemplate, nodeIds[idx])
		participantParams[idx] = participantParam
	}
	return strings.ReplaceAll(moduleParamsTemplate, participantsPlaceholder, strings.Join(participantParams, ","))
}

func partitionNetwork(t *testing.T, enclaveCtx *enclaves.EnclaveContext) {
	partitionedNetworkServices := map[enclaves.PartitionID]map[services.ServiceID]bool{
		firstPartition:  make(map[services.ServiceID]bool),
		secondPartition: make(map[services.ServiceID]bool),
	}
	// half of the nodes go to partition 1, the other half to partition 2
	for _, nodeIdForFirstPartition := range nodeIds[:len(nodeIds)/2] {
		partitionedNetworkServices[firstPartition][renderServiceId(elNodeIdTemplate, nodeIdForFirstPartition)] = true
		partitionedNetworkServices[firstPartition][renderServiceId(clNodeBeaconIdTemplate, nodeIdForFirstPartition)] = true
		partitionedNetworkServices[firstPartition][renderServiceId(clNodeValidatorIdTemplate, nodeIdForFirstPartition)] = true
	}
	for _, nodeIdForSecondPartition := range nodeIds[len(nodeIds)/2:] {
		partitionedNetworkServices[secondPartition][renderServiceId(elNodeIdTemplate, nodeIdForSecondPartition)] = true
		partitionedNetworkServices[secondPartition][renderServiceId(clNodeBeaconIdTemplate, nodeIdForSecondPartition)] = true
		partitionedNetworkServices[secondPartition][renderServiceId(clNodeValidatorIdTemplate, nodeIdForSecondPartition)] = true
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
		healedPartition: make(map[services.ServiceID]bool),
	}
	// All nodes go back into the same partition
	for nodeId := range nodeIds {
		healedNetworkServices[healedPartition][renderServiceId(elNodeIdTemplate, nodeId)] = true
		healedNetworkServices[healedPartition][renderServiceId(clNodeBeaconIdTemplate, nodeId)] = true
		healedNetworkServices[healedPartition][renderServiceId(clNodeValidatorIdTemplate, nodeId)] = true
	}
	healedNetworkConnections := map[enclaves.PartitionID]map[enclaves.PartitionID]enclaves.PartitionConnection{}

	err := enclaveCtx.RepartitionNetwork(
		healedNetworkServices,
		healedNetworkConnections,
		unblockedPartitionConnection,
	)
	require.NoError(t, err, "An error occurred healing the network partition")
}

func getElNodeClientsByServiceID(
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

	printHeader(nodeClientsByServiceIds)
	go func() {
		for true {
			select {
			case <-time.Tick(3 * time.Second):
				printAllNodesInfo(ctx, nodeClientsByServiceIds)
			case <-printingStopChan:
				return
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

func printHeader(nodeClientsByServiceIds map[services.ServiceID]*ethclient.Client) {
	nodeInfoHeaderStr := nodeInfoPrefix
	nodeInfoHeaderLine2Str := nodeInfoPrefix

	sortedServiceIds := make([]services.ServiceID, 0, len(nodeClientsByServiceIds))
	for serviceId, _ := range nodeClientsByServiceIds {
		sortedServiceIds = append(sortedServiceIds, serviceId)
	}
	sort.Slice(sortedServiceIds, func(i, j int) bool {
		return sortedServiceIds[i] < sortedServiceIds[j]
	})
	for _, serviceId := range sortedServiceIds {
		nodeInfoHeaderStr = fmt.Sprintf(nodeInfoHeaderStr+"  %-18s  |", serviceId)
		nodeInfoHeaderLine2Str = fmt.Sprintf(nodeInfoHeaderLine2Str+"  %-05s - %-10s  |", "block", "hash")
	}
	logrus.Infof(nodeInfoHeaderStr)
	logrus.Infof(nodeInfoHeaderLine2Str)
}

func printAllNodesInfo(ctx context.Context, nodeClientsByServiceIds map[services.ServiceID]*ethclient.Client) {
	nodesCurrentBlock := make(map[services.ServiceID]*types.Block, 4)
	for serviceId, client := range nodeClientsByServiceIds {
		nodeBlock, err := getMostRecentNodeBlockWithRetries(ctx, serviceId, client, retriesAttempts, retriesSleepDuration)
		if err != nil && isTestInExecution {
			logrus.Warnf("%-25sAn error occurred getting the most recent block, err:\n%v", serviceId, err.Error())
		}
		nodesCurrentBlock[serviceId] = nodeBlock
	}
	printAllNodesCurrentBlock(nodesCurrentBlock)
}

func printAllNodesCurrentBlock(nodeCurrentBlocks map[services.ServiceID]*types.Block) {
	if nodeCurrentBlocks == nil {
		return
	}
	nodeInfoStr := nodeInfoPrefix
	sortedServiceIds := make([]services.ServiceID, 0, len(nodeCurrentBlocks))
	for serviceId, _ := range nodeCurrentBlocks {
		sortedServiceIds = append(sortedServiceIds, serviceId)
	}
	sort.Slice(sortedServiceIds, func(i, j int) bool {
		return sortedServiceIds[i] < sortedServiceIds[j]
	})

	for _, serviceId := range sortedServiceIds {
		blockInfo := nodeCurrentBlocks[serviceId]
		hash := blockInfo.Hash().Hex()
		shortHash := hash[:5] + ".." + hash[len(hash)-3:]
		nodeInfoStr = fmt.Sprintf(nodeInfoStr+"  %05d - %-10s  |", blockInfo.NumberU64(), shortHash)
	}
	logrus.Infof(nodeInfoStr)
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

func waitUntilAllNodesGetSynced(
	ctx context.Context,
	serviceIds []services.ServiceID,
	nodeClientsByServiceIds map[services.ServiceID]*ethclient.Client,
	minimumBlockNumberConstraint uint64,
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

			if areAllEqual && syncedBlockNumber >= minimumBlockNumberConstraint {
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

func waitUntilNode0AndNodeNDivergeBlockNumbers(
	ctx context.Context,
	node0ServiceId services.ServiceID,
	node0Client *ethclient.Client,
	nodeNServiceId services.ServiceID,
	nodeNClient *ethclient.Client,
	blockNumberToWaitForOnEachNode uint64,
) (uint64, error) {
	node0BlockNumber, node0BlockHash, nodeNBlockNumber, nodeNBlockHash, err := waitForNodesToProduceBlockNumberAfterPartitionWasIntroduced(ctx, node0ServiceId, node0Client, nodeNServiceId, nodeNClient, blockNumberToWaitForOnEachNode)
	if err != nil {
		return 0, stacktrace.Propagate(err, "An error occurred waiting for '%v' and '%v' to produce one new block after partitioning", node0ServiceId, nodeNServiceId)
	}

	if node0BlockNumber != nodeNBlockNumber {
		return 0, stacktrace.NewError("Waiting for '%v' and '%v' to produce one new block after partitioning, they returned a block number that was not equal (resp. '%v' and '%v'). This is a bug in the test case, block number should exactly match here", node0ServiceId, nodeNServiceId, node0BlockNumber, nodeNBlockNumber)
	}
	if node0BlockHash == nodeNBlockHash {
		return 0, stacktrace.NewError("Waiting for '%v' and '%v' to produce one new block after partitioning, they both produced the same block. Producing the same block means that both nodes are still able to communicate somehow. Double check that partitioning was successful, and also check that both nodes part of a different partition.", node0ServiceId, nodeNServiceId)
	}
	mostRecentBlockNumberForNode0, err := getMostRecentNodeBlockWithRetries(ctx, node0ServiceId, node0Client, retriesAttempts, retriesSleepDuration)
	if err != nil {
		return 0, stacktrace.NewError("Unable to retrieve current block for node '%s' after node diverged", node0ServiceId)
	}
	mostRecentBlockNumberForNodeN, err := getMostRecentNodeBlockWithRetries(ctx, nodeNServiceId, nodeNClient, retriesAttempts, retriesSleepDuration)
	if err != nil {
		return 0, stacktrace.NewError("Unable to retrieve current block for node '%s' after node diverged", nodeNServiceId)
	}
	if mostRecentBlockNumberForNode0.NumberU64() > mostRecentBlockNumberForNodeN.NumberU64() {
		return mostRecentBlockNumberForNode0.NumberU64(), nil
	} else {
		return mostRecentBlockNumberForNodeN.NumberU64(), nil
	}
}

func waitForNodesToProduceBlockNumberAfterPartitionWasIntroduced(
	ctx context.Context,
	node0ServiceId services.ServiceID,
	node0Client *ethclient.Client,
	nodeNServiceId services.ServiceID,
	node2Client *ethclient.Client,
	blockNumberToWaitForOnEachNode uint64,
) (uint64, string, uint64, string, error) {

	var wg sync.WaitGroup
	ethNodeBlocksByServiceId := &sync.Map{}
	errorChan := make(chan error, 1)
	defer close(errorChan)

	node0ReachedExpectedBlockNumber := false
	nodeNReachedExpectedBlockNumber := false
	for !node0ReachedExpectedBlockNumber || !nodeNReachedExpectedBlockNumber {
		select {
		// In Eth2, a new block is produced every 12 seconds. Ticking every second is more than enough
		case <-time.Tick(1 * time.Second):
			wg.Add(2)
			//node0
			go func() {
				defer wg.Done()
				logrus.Debugf("Checking block number for node '%s'", node0ServiceId)
				if node0ReachedExpectedBlockNumber {
					logrus.Debugf("Node '%s' already reached block number '%d'", node0ServiceId, blockNumberToWaitForOnEachNode)
					return
				}
				block, err := getMostRecentNodeBlockWithRetries(ctx, node0ServiceId, node0Client, retriesAttempts, retriesSleepDuration)
				if err != nil {
					errorChan <- stacktrace.Propagate(err, "An error occurred getting the most recent node block for service '%v'", node0ServiceId)
					return
				}
				if block.NumberU64() == blockNumberToWaitForOnEachNode {
					ethNodeBlocksByServiceId.Store(node0ServiceId, block)
					logrus.Infof("Node '%s' produced one block after partitioning (block number '%d', block hash '%s')", node0ServiceId, block.NumberU64(), block.Hash().Hex())
				}
			}()

			//nodeN
			go func() {
				defer wg.Done()
				logrus.Debugf("Checking block number for node '%s'", nodeNServiceId)
				if nodeNReachedExpectedBlockNumber {
					logrus.Debugf("Node '%s' already reached block number '%d'", nodeNServiceId, blockNumberToWaitForOnEachNode)
					return
				}
				block, err := getMostRecentNodeBlockWithRetries(ctx, nodeNServiceId, node2Client, retriesAttempts, retriesSleepDuration)
				if err != nil {
					errorChan <- stacktrace.Propagate(err, "An error occurred getting the most recent node block for service '%v'", nodeNServiceId)
					return
				}
				if block.NumberU64() == blockNumberToWaitForOnEachNode {
					ethNodeBlocksByServiceId.Store(nodeNServiceId, block)
					logrus.Infof("Node '%s' produced one block after partitioning (block number '%d', block hash '%s')", nodeNServiceId, block.NumberU64(), block.Hash().Hex())
				}
			}()
			wg.Wait()
			_, node0ReachedExpectedBlockNumber = ethNodeBlocksByServiceId.Load(node0ServiceId)
			_, nodeNReachedExpectedBlockNumber = ethNodeBlocksByServiceId.Load(nodeNServiceId)
		case err := <-errorChan:
			if err != nil {
				return 0, "", 0, "", stacktrace.Propagate(err, "An error occurred checking for next block number and hash")
			}
			return 0, "", 0, "", stacktrace.NewError("Something unexpected happened, a new value was received from the error channel but it's nil")
		}
	}

	uncastedNode0Block, loaded := ethNodeBlocksByServiceId.LoadAndDelete(node0ServiceId)
	if !loaded {
		return 0, "", 0, "", stacktrace.NewError("An error occurred loading the node's block for service with ID '%v', the value for key '%v' was not loaded", node0ServiceId, node0ServiceId)
	}
	node0Block, ok := uncastedNode0Block.(*types.Block)
	if !ok {
		return 0, "", 0, "", stacktrace.NewError("An error occurred loading the node's block for service with ID '%v', the value for key '%v' was present but of an unexpected type", node0ServiceId, node0ServiceId)
	}

	uncastedNodeNBlock, loaded := ethNodeBlocksByServiceId.LoadAndDelete(nodeNServiceId)
	if !loaded {
		return 0, "", 0, "", stacktrace.NewError("An error occurred loading the node's block for service with ID '%v', the value for key '%v' was not loaded", nodeNServiceId, nodeNServiceId)
	}
	nodeNBlock, ok := uncastedNodeNBlock.(*types.Block)
	if !ok {
		return 0, "", 0, "", stacktrace.NewError("An error occurred loading the node's block for service with ID '%v', the value for key '%v' was present but of an unexpected type", nodeNServiceId, nodeNServiceId)
	}

	return node0Block.NumberU64(), node0Block.Hash().Hex(), nodeNBlock.NumberU64(), nodeNBlock.Hash().Hex(), nil
}

func renderServiceId(template string, nodeId int) services.ServiceID {
	return services.ServiceID(fmt.Sprintf(template, nodeId))
}
