ethereum_network_partition = import_module("github.com/kurtosis-tech/example/ethereum-network-partition-test/main.star")


def run(plan, args):
	# TODO: when we have multiple example, maybe do a switch here. For now, run the only one we have
	ethereum_network_partition.run(plan)
