main_cassandra_module = import_module("github.com/kurtosis-tech/cassandra-package/main.star")

SUBNETWORK_1 = "first_sub_network"
SUBNETWORK_2 = "second_sub_network"

def run(plan, args):
    plan.print("Spinning up the Cassandra Package")
    cassandra_run_output = main_cassandra_module.run(plan, args)

    if len(cassandra_run_output["node_names"]) < 2:
        fail("Less than 2 nodes were spun up; cant do partitioning")

    simulate_network_failure(plan, cassandra_run_output)
    heal_and_verify(plan, cassandra_run_output)


def simulate_network_failure(plan, cassandra_run_output):
    """
    this splits the existing network into two
    the first containing all the nodes but the last node
    the second containing only the last node
    """

    plan.print("Partitioning Cassandra Nodes into  2 different Networks")

    plan.set_connection(config=kurtosis.connection.BLOCKED)

    all_but_last_node = cassandra_run_output["node_names"][:-1]
    last_node_name = cassandra_run_output["node_names"][-1]

    for node_name in all_but_last_node:
        plan.update_service(node_name, config=UpdateServiceConfig(subnetwork=SUBNETWORK_1))

    plan.update_service(last_node_name, config=UpdateServiceConfig(subnetwork=SUBNETWORK_2))

    check_un_nodes = "nodetool status | grep UN | wc -l | tr -d '\n'"

    check_un_nodes_recipe = ExecRecipe(
        service_name = main_cassandra_module.get_first_node_name(),
        command = ["/bin/sh", "-c", check_un_nodes],
    )

    plan.wait(check_un_nodes_recipe, "output", "==", str(len(cassandra_run_output["node_names"])-1))

    check_dn_nodes = "nodetool status | grep DN | wc -l | tr -d '\n'"

    check_dn_nodes_recipe = ExecRecipe(
        service_name = main_cassandra_module.get_first_node_name(),
        command = ["/bin/sh", "-c", check_dn_nodes],
    )

    result = plan.exec(check_dn_nodes_recipe)

    plan.assert(result["output"], "==", "1")


def heal_and_verify(plan, cassandra_run_output):
    """ 
    this puts all the nodes back into the same network and
    verifies the cluster is healthy
    """

    plan.print("Healing Partitions and Verifying Cluster is healthy")

    last_node_name = cassandra_run_output["node_names"][-1]

    plan.update_service(last_node_name, config=UpdateServiceConfig(subnetwork=SUBNETWORK_1))

    node_tool_check = "nodetool status | grep UN | wc -l | tr -d '\n'"

    check_nodes_are_up = ExecRecipe(
        service_name = main_cassandra_module.get_first_node_name(),
        command = ["/bin/sh", "-c", node_tool_check],
    )

    plan.wait(check_nodes_are_up, "output", "==", str(len(cassandra_run_output["node_names"])))
