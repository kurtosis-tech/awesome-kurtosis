eth_package = import_module("github.com/leoporoli/eth-network-package/main.star")

PARTICIPANT_CONFIG = {
    "el_client_type": "geth",
    "el_client_image": "ethereum/client-go:v1.10.25",
    "cl_client_type": "lighthouse",
    "cl_client_image": "sigp/lighthouse:v3.1.2",
}

# This is hardcoded in the eth-package.
# TODO: Maybe rework the object this package returned to get those node ids dynamically
EL_NODE_ID_PATTERN = "el-client-{0}"
CL_BEACON_NODE_ID_PATTERN = "cl-client-{0}-beacon"
CL_VALIDATOR_NODE_ID_PATTERN = "cl-client-{0}-validator"


def run_eth_package(plan, number_of_nodes):
    """
    Runs the starlark eth_package that spins up an Ethereum network
    """
    eth_package_args = get_eth_package_args(number_of_nodes)
    eth_package.run(plan, eth_package_args)


def get_eth_package_args(number_of_nodes):
    participants = []
    for _ in range(0, number_of_nodes):
        participants.append(PARTICIPANT_CONFIG)
    return {
        "participants": participants
    }

def el_node_id(id_int):
    return EL_NODE_ID_PATTERN.format(id_int)


def cl_validator_node_id(id_int):
    return CL_VALIDATOR_NODE_ID_PATTERN.format(id_int)


def cl_beacon_node_id(id_int):
    return CL_BEACON_NODE_ID_PATTERN.format(id_int)
