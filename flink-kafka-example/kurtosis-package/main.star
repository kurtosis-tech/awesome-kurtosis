main_flink_module = import_module("github.com/kurtosis-tech/flink-package/main.star")

FLINK_LIB_JARS_EXTRA_ARG_NAME = "flink-lib-jars-extra"
FLINK_JOB_JAR_PATH = "../flink-kafka-job/build/run.jar"
FLINK_JOB_MANAGER_SERVICE_NAME = "jobmanager"
FLINK_JOB_MANAGER_API_PORT = 8081

FLINK_JOB_LOADER_IMAGE = "kurtosistech/flink-kafka-example-job-loader"
FLINK_JOB_LOADER_SERVICE_NAME = "flink-job-loader"
FLINK_JOB_LOADER_RUN_JAR = "run.jar"

ZOOKEEPER_IMAGE = "bitnami/zookeeper:3.8.1"
ZOOKEEPER_SERVICE_NAME = "zookeeper"
ZOOKEEPER_PORT_NUMBER = 2181

KAFKA_IMAGE = "bitnami/kafka:3.4.0"
KAFKA_SERVICE_NAME = "kafka"
KAFKA_SERVICE_PORT_INTERNAL_NUMBER = 9092
KAFKA_SERVICE_PORT_EXTERNAL_NUMBER = 9093

KAFKA_INPUT_TOPIC = "words"
KAFKA_OUTPUT_TOPIC = "words-counted"
WORD = "kurtosis"
WORDS = [WORD, WORD, WORD]

def run(plan, args):
    ### Start Flink cluster
    main_flink_module.run(plan, args)

    ### Start the Kafka cluster: first Zookeeper then Kafka itself
    create_service_zookeeper(plan, ZOOKEEPER_SERVICE_NAME, ZOOKEEPER_IMAGE, ZOOKEEPER_PORT_NUMBER)
    create_service_kafka(plan, KAFKA_SERVICE_NAME, ZOOKEEPER_SERVICE_NAME, KAFKA_SERVICE_PORT_INTERNAL_NUMBER, KAFKA_SERVICE_PORT_EXTERNAL_NUMBER)

    ### Check that the Kafka Cluster is ready:
    kafka_bootstrap_server_host_port = "%s:%d" % (KAFKA_SERVICE_NAME, KAFKA_SERVICE_PORT_EXTERNAL_NUMBER)
    check_kafka_is_ready(plan, KAFKA_SERVICE_NAME, KAFKA_SERVICE_PORT_EXTERNAL_NUMBER)

    ### Create the input and output topics
    create_topic(KAFKA_INPUT_TOPIC, plan, kafka_bootstrap_server_host_port)
    create_topic(KAFKA_OUTPUT_TOPIC, plan, kafka_bootstrap_server_host_port)

    ### Publish data into the input topic:
    for word in WORDS: publish_word_to_topic(word, plan, kafka_bootstrap_server_host_port, KAFKA_INPUT_TOPIC)

    ### When Kafka cluster is ready, upload and run flink job:
    create_service_flink_job_loader(plan, FLINK_JOB_LOADER_SERVICE_NAME, FLINK_JOB_LOADER_IMAGE, FLINK_JOB_MANAGER_SERVICE_NAME, FLINK_JOB_MANAGER_API_PORT, FLINK_JOB_LOADER_RUN_JAR)

    verify_counts(plan, kafka_bootstrap_server_host_port, KAFKA_OUTPUT_TOPIC, KAFKA_SERVICE_NAME)

    return

def create_service_flink_job_loader(plan, service_name, image, job_manager_host_name, job_manager_api_port, run_jar):
    config = ServiceConfig(
        image=image,
        env_vars={
            "FLINK_HOST": job_manager_host_name,
            "FLINK_API_PORT": str(job_manager_api_port),
            "RUN_JAR": run_jar,
        }
    )
    service = plan.add_service(name=service_name, config=config)
    plan.print("Created service: " + str(service.hostname))
    return service

def create_service_zookeeper(plan, zookeeper_service_name, zookeeper_image, zookeeper_port_number):
    zookeeper_config = ServiceConfig(
        image=zookeeper_image,
        ports={
            "zookeeper": PortSpec(
                number=zookeeper_port_number,
            ),
        },
        env_vars={
            "ALLOW_ANONYMOUS_LOGIN": "yes",
        }
    )
    zookeeper_service = plan.add_service(name=zookeeper_service_name, config=zookeeper_config)
    plan.print("Created Zookeeper service: " + str(zookeeper_service.hostname))
    return zookeeper_service


def create_service_kafka(plan, kafka_service_name, zookeeper_service_name, kafka_service_port_internal_number,
                         kafka_service_port_external_number):
    kafka_config = ServiceConfig(
        image=KAFKA_IMAGE,
        ports={
            "bootstrap-server-internal": PortSpec(number=kafka_service_port_internal_number),
            "bootstrap-server-external": PortSpec(number=kafka_service_port_external_number),
        },
        env_vars={
            "KAFKA_ENABLE_KRAFT": "no",
            "KAFKA_CFG_ZOOKEEPER_CONNECT": "%s:2181" % zookeeper_service_name,
            "KAFKA_CFG_LISTENERS": "INTERNAL://%s:%d,EXTERNAL://0.0.0.0:%d" % (kafka_service_name, kafka_service_port_internal_number, kafka_service_port_external_number),
            "KAFKA_CFG_ADVERTISED_LISTENERS": "INTERNAL://%s:%d,EXTERNAL://localhost:%d" % (kafka_service_name, kafka_service_port_internal_number, kafka_service_port_external_number),
            "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP": "INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT",
            "KAFKA_CFG_INTER_BROKER_LISTENER_NAME": "INTERNAL",
            "KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR": "1",
            "ALLOW_PLAINTEXT_LISTENER": "yes",
            "KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE": "false",
        },
        # TODO Only for development, remove before final PR:
        public_ports={
            "bootstrap-server-internal": PortSpec(number=kafka_service_port_internal_number),
            "bootstrap-server-external": PortSpec(number=kafka_service_port_external_number),
        }
    )
    kafka_service = plan.add_service(name=kafka_service_name, config=kafka_config)
    plan.print("Created kafka service: " + str(kafka_service.hostname))
    return kafka_service


def check_kafka_is_ready(plan, kafka_service_name, kafka_service_port_external_number):
    kafka_bootstrap_server_host_port = "%s:%d" % (kafka_service_name, kafka_service_port_external_number)
    exec_check_kafka_cluster = ExecRecipe(
        command=[
            "/bin/sh",
            "-c",
            "/opt/bitnami/kafka/bin/kafka-features.sh --bootstrap-server %s describe" % kafka_bootstrap_server_host_port
        ],
    )
    plan.wait(
        service_name=kafka_service_name,
        recipe=exec_check_kafka_cluster,
        field="code",
        assertion="==",
        target_value=0,
        timeout="30s",
    )
    return


def create_topic(topic, plan, kafka_bootstrap_server_host_port):
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


def publish_word_to_topic(word, plan, kafka_bootstrap_server_host_port, kafka_input_topic):
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

def verify_counts(plan, kafka_bootstrap_server_host_port, kafka_output_topic, service_name):
    plan.print("Checking kafka topic for kurtosis count")
    exec_check_data = ExecRecipe(
        command=[
            "/bin/sh",
            "-c",
            "./opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server %s --topic %s --max-messages 1 --group cli-test --from-beginning 2>/dev/null" % (kafka_bootstrap_server_host_port, kafka_output_topic),
        ],
        extract={
            "word-count": 'fromjson | .word == "kurtosis" and .count == 3'
        },
    )
    plan.wait(
        service_name=service_name,
        recipe=exec_check_data,
        field="extract.word-count",
        assertion="==",
        target_value=True,
        timeout="15s",
    )

    return
