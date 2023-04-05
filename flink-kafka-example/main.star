main_flink_module = import_module("github.com/kurtosis-tech/flink-package/main.star")
# Maybe strimzi for k8s?
KAFKA_IMAGE = "bitnami/kafka:3.2.3"
ZOOKEEPER_IMAGE = "bitnami/zookeeper:3.8.1"
ZOOKEEPER_SERVICE_NAME="zookeeper"
ZOOKEEPER_PORT_NUMBER=2181
KAFKA_SERVICE_NAME="kafka"
KAFKA_SERVICE_PORT_NUMBER=9092

def run(plan, args):
    plan.print("Spinning up the Flink Package")
    flink_run_output = main_flink_module.run(plan, args)

    zookeeper_config = ServiceConfig(
        image = ZOOKEEPER_IMAGE,
        ports = {
            "zookeeper": PortSpec(
                number = ZOOKEEPER_PORT_NUMBER,
            ),
        },
        env_vars = {
            "ALLOW_ANONYMOUS_LOGIN": "yes",
        }

    )
    zookeeper_service = plan.add_service(name = ZOOKEEPER_SERVICE_NAME, config = zookeeper_config)
    plan.print("Created zookeeper service: "+str(zookeeper_service.hostname))

    kafka_config = ServiceConfig(
        image = KAFKA_IMAGE,
        ports = {
            "bootstrap-server": PortSpec(
                number = KAFKA_SERVICE_PORT_NUMBER,
#                transport_protocol = "TCP",
#                application_protocol = "http",
            ),
        },
        env_vars = {
#            "KAFKA_ENABLE_KRAFT": "yes",
            "ALLOW_PLAINTEXT_LISTENER": "yes",
            "KAFKA_CFG_BROKER_ID": "1",
            "KAFKA_CFG_ZOOKEEPER_CONNECT" : "zookeeper:2181"
        }
    )
    kafka_service = plan.add_service(name = KAFKA_SERVICE_NAME, config = kafka_config)
    plan.print("Created kafka service: "+str(kafka_service.hostname))


    # if len(cassandra_run_output["node_names"]) < 2:
    #     fail("Less than 2 nodes were spun up; cant do partitioning")

    # simulate_network_failure(plan, cassandra_run_output)
    # heal_and_verify(plan, cassandra_run_output)

