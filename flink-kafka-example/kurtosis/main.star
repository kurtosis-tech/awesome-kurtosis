
# TODO: CHange to 1.17.0:
main_flink_module = import_module("github.com/kurtosis-tech/flink-package/main.star")
# Maybe strimzi for k8s?
KAFKA_IMAGE = "bitnami/kafka:latest"  #3.2.3"
ZOOKEEPER_IMAGE = "bitnami/zookeeper:latest"  #3.8.1"
ZOOKEEPER_SERVICE_NAME = "zookeeper"
ZOOKEEPER_PORT_NUMBER = 2181
KAFKA_SERVICE_NAME = "kafka"
KAFKA_SERVICE_PORT_INTERNAL_NUMBER = 9092
KAFKA_SERVICE_PORT_EXTERNAL_NUMBER = 9093

# KCAT_IMAGE = "edenhill/kcat:1.7.1"
# KCAT_SERVICE_NAME = "KCAT"
KAFKA_INPUT_TOPIC = "words"
KAFKA_OUTPUT_TOPIC = "words-counted"

wordsInAString = "Kurtosis is a composable build system for multi-container test environments. Kurtosis makes it easier for developers to set up test environments that require dynamic setup logic (e.g. passing IPs or runtime-generated data between services) or programmatic data seeding."

def run(plan, args):
    plan.print("Spinning up the Flink Package")
    flink_run_output = main_flink_module.run(plan, args)

    zookeeper_config = ServiceConfig(
        image=ZOOKEEPER_IMAGE,
        ports={
            "zookeeper": PortSpec(
                number=ZOOKEEPER_PORT_NUMBER,
            ),
        },
        env_vars={
            "ALLOW_ANONYMOUS_LOGIN": "yes",
        }

    )
    zookeeper_service = plan.add_service(name=ZOOKEEPER_SERVICE_NAME, config=zookeeper_config)
    plan.print("Created zookeeper service: " + str(zookeeper_service.hostname))

    kafka_config = ServiceConfig(
        image=KAFKA_IMAGE,
        ports={
            # "bootstrap-server-internal": PortSpec(number = KAFKA_SERVICE_PORT_INTERNAL_NUMBER),
            "bootstrap-server-external": PortSpec(number=KAFKA_SERVICE_PORT_EXTERNAL_NUMBER),
        },
        # TODO EXTERNAL: only for development, remove before final PR:
        env_vars={
            "KAFKA_CFG_ZOOKEEPER_CONNECT": "zookeeper:2181",
            "KAFKA_CFG_LISTENERS": "INTERNAL://kafka:9092,EXTERNAL://0.0.0.0:9093",
            "KAFKA_CFG_ADVERTISED_LISTENERS": "INTERNAL://kafka:9092,EXTERNAL://localhost:9093",
            "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP": "INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT",
            "KAFKA_CFG_INTER_BROKER_LISTENER_NAME": "INTERNAL",
            "KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR": "1",
            #            "KAFKA_CFG_BROKER_ID": "1",
            "ALLOW_PLAINTEXT_LISTENER": "yes",
            "KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE": "false",
        },
        # TODO Only for development, remove before final PR:
        public_ports={
            "bootstrap-server-external": PortSpec(number=KAFKA_SERVICE_PORT_EXTERNAL_NUMBER),
        }
    )
    kafka_service = plan.add_service(name=KAFKA_SERVICE_NAME, config=kafka_config)
    plan.print("Created kafka service: " + str(kafka_service.hostname))

    kafka_bootstrap_server_host_port = "%s:%d" % (KAFKA_SERVICE_NAME, KAFKA_SERVICE_PORT_EXTERNAL_NUMBER)
    ### Check that the Kafka Cluster is ready:
    exec_check_kafka_cluster = ExecRecipe(
        command=[
            "/bin/sh",
            "-c",
            "/opt/bitnami/kafka/bin/kafka-features.sh --bootstrap-server %s describe" % kafka_bootstrap_server_host_port
        ],
    )
    plan.wait(
        service_name=KAFKA_SERVICE_NAME,
        recipe=exec_check_kafka_cluster,
        field="code",
        assertion="==",
        target_value=0,
        timeout="30s",
    )

    ### Add the input and output topics
    createTopic(KAFKA_INPUT_TOPIC, plan, kafka_bootstrap_server_host_port)
    createTopic(KAFKA_OUTPUT_TOPIC, plan, kafka_bootstrap_server_host_port)

    ### Publish data into the input topic:
    words = wordsInAString.split()
    for word in words:
        publishWordToTopic(word, plan, kafka_bootstrap_server_host_port, KAFKA_INPUT_TOPIC)

    return

def createTopic(topic, plan, kafka_bootstrap_server_host_port):
    exec_add_input_topic = ExecRecipe(
        command=[
            "/bin/sh",
            "-c",
            "/opt/bitnami/kafka/bin/kafka-topics.sh --bootstrap-server %s --create --topic %s" % (
            kafka_bootstrap_server_host_port, topic)
        ],
    )
    result = plan.exec(service_name=KAFKA_SERVICE_NAME, recipe=exec_add_input_topic)
    return result


def publishWordToTopic(word, plan, kafka_bootstrap_server_host_port, kafka_input_topic):
    exec_add_data = ExecRecipe(
        command=[
            "/bin/sh",
            "-c",
            "echo '%s' | ./opt/bitnami/kafka/bin/kafka-console-producer.sh --bootstrap-server %s --topic %s" % (
            word, kafka_bootstrap_server_host_port, kafka_input_topic),
        ]
    )
    result = plan.exec(
        service_name=KAFKA_SERVICE_NAME,
        recipe=exec_add_data,
    )
    return result
