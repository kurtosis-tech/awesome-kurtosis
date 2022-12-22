eth2 = import_module("github.com/kurtosis-tech/example/ethereum-network-partition-test/eth2_starlark_package.star")
ethereum_helpers = import_module("github.com/kurtosis-tech/example/ethereum-network-partition-test/ethereum_helpers.star")

NUM_PARTICIPANTS = 4

MAIN_NETWORK = "main_network"
ISOLATED_NETWORK = "isolated_network"

CHECKPOINT_1_NODES_SYNCED = "0x2" # block number 2
CHECKPOINT_2_NODES_OUT_OF_SYNC = "0xc" # block number 12
CHECKPOINT_3_NODES_SYNCED = "0x16" # block number 22


def run(plan):
    plan.print("Spinning up an Ethereum network with '{0}' nodes".format(NUM_PARTICIPANTS))
    eth2.run_eth2_package(plan, NUM_PARTICIPANTS)

    network_topology = assign_nodes_subnetwork(plan)
    plan.print("Starting test with the following network topology: \n{0}".format(network_topology))

    assert_all_nodes_synced_at_block(plan, CHECKPOINT_1_NODES_SYNCED)
    plan.print("Block number '{0}' for all services: \n{1}".format(CHECKPOINT_1_NODES_SYNCED, get_block_all_nodes(plan, CHECKPOINT_1_NODES_SYNCED)))

    plan.set_connection((MAIN_NETWORK, ISOLATED_NETWORK), kurtosis.connection.BLOCKED)
    plan.print("Subnetwork '{0}' was disconnected from '{1}'".format(ISOLATED_NETWORK, MAIN_NETWORK))

    assert_nodes_out_of_sync_at_block(plan, CHECKPOINT_2_NODES_OUT_OF_SYNC)
    plan.print("Block number '{0}' for all services: \n{1}".format(CHECKPOINT_2_NODES_OUT_OF_SYNC, get_block_all_nodes(plan, CHECKPOINT_2_NODES_OUT_OF_SYNC)))

    plan.remove_connection((MAIN_NETWORK, ISOLATED_NETWORK))
    assert_all_nodes_synced_at_block(plan, CHECKPOINT_3_NODES_SYNCED)
    plan.print("Block number '{0}' for all services: \n{1}".format(CHECKPOINT_3_NODES_SYNCED, get_block_all_nodes(plan, CHECKPOINT_3_NODES_SYNCED)))

def assign_nodes_subnetwork(plan):
    """
    Assigns half of the nodes to subnetwork MAIN_NETWORK and the other half to ISOLATED_NETWORK.

    The connection between the 2 subnetworks are not updated in this function
    """
    all_nodes = []
    for i in range(0, NUM_PARTICIPANTS):
        # each ETH node is composed of a tuple (EL, CL_VALIDATOR, CL_BEACON)
        # We need to update the three of them
        all_nodes.append((
            eth2.el_node_id(i),
            eth2.cl_beacon_node_id(i),
            eth2.cl_validator_node_id(i),
        ))
    main_nodes = all_nodes[:len(all_nodes)//2]
    isolated_nodes = all_nodes[len(all_nodes)//2:]
    for node in main_nodes:
        for i in range(3):
            plan.update_service(node[i], UpdateServiceConfig(
                subnetwork=MAIN_NETWORK,
            ))
    for node in isolated_nodes:
        for i in range(3):
            plan.update_service(node[i], UpdateServiceConfig(
                subnetwork=ISOLATED_NETWORK,
            ))
    return {
        MAIN_NETWORK: main_nodes,
        ISOLATED_NETWORK: isolated_nodes,
    }

def wait_all_nodes_at_block(plan, block_number_hex):
    """
    This function blocks until all nodes are passed block number `block_number_hex`. The wait happens one node at a
    time, starting with the node #0.
    """
    for i in range(0, NUM_PARTICIPANTS):
        node_id = eth2.el_node_id(i)
        ethereum_helpers.wait_until_node_reached_block(plan, node_id, block_number_hex)

def assert_all_nodes_synced_at_block(plan, block_number_hex):
    """
    This function asserts all nodes were synced at block number `block_number_hex`. It waits as much time as
    needed for all nodes to be passed this block number.

    It throws an error if block hashes are different.
    """
    wait_all_nodes_at_block(plan, block_number_hex)
    block_hash_by_node = get_block_all_nodes(plan, block_number_hex)

    # check that node have all the same hash doing a 2-by-2 comparison
    for i in range(0, NUM_PARTICIPANTS-1):
        node_id = eth2.el_node_id(i)
        next_node_id = eth2.el_node_id(i + 1)
        plan.assert(
            value=block_hash_by_node[node_id],
            assertion="==",
            target_value=block_hash_by_node[next_node_id],
        )

def assert_nodes_out_of_sync_at_block(plan, block_number_hex):
    """
    This function asserts that the first node and the last node were out of sync at block number `block_number_hex`.
    It waits as much time as needed for all nodes to be passed this block number before running the assertion.

    It throws an error if first node and last node block hash were identical
    """
    wait_all_nodes_at_block(plan, block_number_hex)
    block_hash_by_node = get_block_all_nodes(plan, block_number_hex)

    # check that first and last node have diverged
    first_node = eth2.el_node_id(0)
    last_node = eth2.el_node_id(NUM_PARTICIPANTS-1)
    plan.assert(
        value=block_hash_by_node[first_node],
        assertion="!=",
        target_value=block_hash_by_node[last_node],
    )

def get_block_all_nodes(plan, block_number_hex):
    """
    Helper function that returns a dictionary node_id -> block_hash for the block number `block_number_hex`
    """
    block_hash_by_node = {}
    for i in range(0, NUM_PARTICIPANTS):
        node_id = eth2.el_node_id(i)
        block = ethereum_helpers.get_block(plan, node_id, block_number_hex)
        block_hash_by_node[node_id] = block.hash
    return block_hash_by_node
