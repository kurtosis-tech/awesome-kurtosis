# main_flink_module = import_module("github.com/kurtosis-tech/flink-package/main.star")
# Maybe strimzi for k8s?
KAFKA_IMAGE = "bitnami/kafka:latest" #3.2.3"
ZOOKEEPER_IMAGE = "bitnami/zookeeper:latest" #3.8.1"
ZOOKEEPER_SERVICE_NAME="zookeeper"
ZOOKEEPER_PORT_NUMBER=2181
KAFKA_SERVICE_NAME="kafka"
KAFKA_SERVICE_PORT_INTERNAL_NUMBER=9092
KAFKA_SERVICE_PORT_EXTERNAL_NUMBER=9093

# KCAT_IMAGE = "edenhill/kcat:1.7.1"
# KCAT_SERVICE_NAME = "KCAT"
KAFKA_INPUT_TOPIC="words"
KAFKA_OUTPUT_TOPIC="words-counted"

def run(plan, args):
    plan.print("Spinning up the Flink Package")
    # flink_run_output = main_flink_module.run(plan, args)
    #
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
            # "bootstrap-server-internal": PortSpec(number = KAFKA_SERVICE_PORT_INTERNAL_NUMBER),
            "bootstrap-server-external": PortSpec(number = KAFKA_SERVICE_PORT_EXTERNAL_NUMBER),
        },
        # TODO EXTERNAL: only for development, remove before final PR:
        env_vars = {
            "KAFKA_CFG_ZOOKEEPER_CONNECT" : "zookeeper:2181",
            "KAFKA_CFG_LISTENERS": "INTERNAL://kafka:9092,EXTERNAL://0.0.0.0:9093",
            "KAFKA_CFG_ADVERTISED_LISTENERS": "INTERNAL://kafka:9092,EXTERNAL://localhost:9093",
            "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP": "INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT",
            "KAFKA_CFG_INTER_BROKER_LISTENER_NAME": "INTERNAL",
            "KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR": "1",
#            "KAFKA_CFG_BROKER_ID": "1",
            "ALLOW_PLAINTEXT_LISTENER": "yes",
        }
    )
    kafka_service = plan.add_service(name = KAFKA_SERVICE_NAME, config = kafka_config)
    plan.print("Created kafka service: "+str(kafka_service.hostname))

    kafka_bootstrap_server_host_port = "%s:%d" % (KAFKA_SERVICE_NAME,KAFKA_SERVICE_PORT_EXTERNAL_NUMBER)
    ### Check that the Kafka Cluster is ready:
    exec_check_kafka_cluster = ExecRecipe(
        command = [
            "/bin/sh",
            "-c",
            "/opt/bitnami/kafka/bin/kafka-features.sh --bootstrap-server %s describe" % kafka_bootstrap_server_host_port
        ],
    )
    plan.wait(
        service_name=KAFKA_SERVICE_NAME,
        recipe=exec_check_kafka_cluster,
        field = "code",
        assertion = "==",
        target_value = 0,
        timeout = "30s",
    )

    ### Add the input and output topics
    exec_add_input_topic = ExecRecipe(
        command = [
            "/bin/sh",
            "-c",
            "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server %s --create --topic %s" % (kafka_bootstrap_server_host_port, KAFKA_INPUT_TOPIC)
        ],
    )
    plan.exec(service_name=KAFKA_SERVICE_NAME, recipe=exec_add_input_topic)
    exec_add_output_topic = ExecRecipe(
        command = [
            "/bin/sh",
            "-c",
            "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server %s --create --topic %s" % (kafka_bootstrap_server_host_port, KAFKA_OUTPUT_TOPIC)
        ],
    )
    plan.exec(service_name=KAFKA_SERVICE_NAME, recipe=exec_add_output_topic)

    ### Load the data
    exec_add_data = ExecRecipe(
        command = [
            "/bin/sh",
            "-c",
            "echo 'test' | ./opt/bitnami/kafka/bin/kafka-console-producer.sh --bootstrap-server %s --topic %s" % (kafka_bootstrap_server_host_port, KAFKA_INPUT_TOPIC),
        ]
    )
    result = plan.exec(
        service_name=KAFKA_SERVICE_NAME,
        recipe = exec_add_data,
    )
    plan.print(result["output"])
    plan.print(result["code"])


#     kcat_config = ServiceConfig(
#         image = KCAT_IMAGE,
#         entrypoint = [
#             "KCAT -b kafka:9093 -L",
# #            "echo '{\"word\":\"this\"}' | kcat -b kafka:9093 -P -t words",
#         ],
#     )
#     kcat_service = plan.add_service(name = KCAT_SERVICE_NAME, config = kcat_config)

#
#
#     check_nodes_are_up = ExecRecipe(
#         service_name = get_first_node_name(),
#         command = ["/bin/sh", "-c", node_tool_check],
#     )
#
# plan.wait(check_nodes_are_up, "output", "==", str(num_nodes))

# echo '{"word":"this"}' | kcat -b localhost:9093 -P -t test


    # if len(cassandra_run_output["node_names"]) < 2:
    #     fail("Less than 2 nodes were spun up; cant do partitioning")

    # simulate_network_failure(plan, cassandra_run_output)
    # heal_and_verify(plan, cassandra_run_output)
