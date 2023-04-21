# main_flink_module = import_module("github.com/adschwartz/flink-package/main.star")
# main_flink_module = import_module("github.com/kurtosis-tech/flink-package/main.star")
# FLINK_LIB_JARS_EXTRA_ARG_NAME = "flink-lib-jars-extra"

KAFKA_IMAGE = "bitnami/kafka:3.4.0"
ZOOKEEPER_IMAGE = "bitnami/zookeeper:3.8.1"
ZOOKEEPER_SERVICE_NAME = "zookeeper"
ZOOKEEPER_PORT_NUMBER = 2181
KAFKA_SERVICE_NAME = "kafka"
KAFKA_SERVICE_PORT_INTERNAL_NUMBER = 9092
KAFKA_SERVICE_PORT_EXTERNAL_NUMBER = 9093

KAFKA_INPUT_TOPIC = "words"
KAFKA_OUTPUT_TOPIC = "words-counted"

wordsInAString = "kurtosis runs in kurtosis running in kurtosis"

FLINK_JOB_JAR_PATH = "../flink-kafka-job/build/run.jar"


def run(plan, args):
    # uploaded_files = upload_files(plan)
    # plan.print(uploaded_files)

    # args.update({FLINK_LIB_JARS_EXTRA_ARG_NAME:uploaded_files})
    # plan.print(args)

    # flink_run_output = main_flink_module.run(plan, args)
    # flink_upload_output = upload_flink_job(plan, FLINK_JOB_JAR_PATH)

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
            "bootstrap-server-internal": PortSpec(number=KAFKA_SERVICE_PORT_INTERNAL_NUMBER),
            # "bootstrap-server-external": PortSpec(number=KAFKA_SERVICE_PORT_EXTERNAL_NUMBER),
        },
        env_vars={
            "KAFKA_CFG_ZOOKEEPER_CONNECT": "zookeeper:2181",
            "KAFKA_CFG_LISTENERS": "INTERNAL://kafka:9092,EXTERNAL://0.0.0.0:9093",
            "KAFKA_CFG_ADVERTISED_LISTENERS": "INTERNAL://kafka:9092,EXTERNAL://localhost:9093",
            "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP": "INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT",
            "KAFKA_CFG_INTER_BROKER_LISTENER_NAME": "INTERNAL",
            "KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR": "1",
            # "KAFKA_CFG_BROKER_ID": "1",
            "ALLOW_PLAINTEXT_LISTENER": "yes",
            "KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE": "false",
        },
        # # TODO Only for development, remove before final PR:
        # public_ports={
        #     "bootstrap-server-external": PortSpec(number=KAFKA_SERVICE_PORT_EXTERNAL_NUMBER),
        # }
    )
    kafka_service = plan.add_service(name=KAFKA_SERVICE_NAME, config=kafka_config)
    plan.print("Created kafka service: " + str(kafka_service.hostname))

    # kafka_bootstrap_server_host_port = "%s:%d" % (KAFKA_SERVICE_NAME, KAFKA_SERVICE_PORT_EXTERNAL_NUMBER)
    # ### Check that the Kafka Cluster is ready:
    # exec_check_kafka_cluster = ExecRecipe(
    #     command=[
    #         "/bin/sh",
    #         "-c",
    #         "/opt/bitnami/kafka/bin/kafka-features.sh --bootstrap-server %s describe" % kafka_bootstrap_server_host_port
    #     ],
    # )
    # plan.wait(
    #     service_name=KAFKA_SERVICE_NAME,
    #     recipe=exec_check_kafka_cluster,
    #     field="code",
    #     assertion="==",
    #     target_value=0,
    #     timeout="30s",
    # )
    #
    # ### Add the input and output topics
    # create_topic(KAFKA_INPUT_TOPIC, plan, kafka_bootstrap_server_host_port)
    # create_topic(KAFKA_OUTPUT_TOPIC, plan, kafka_bootstrap_server_host_port)
    #
    # ### Publish data into the input topic:
    # words = wordsInAString.split()
    # for word in words:
    #     publish_word_to_topic(word, plan, kafka_bootstrap_server_host_port, KAFKA_INPUT_TOPIC)
    #
    # verify_counts("kurtosis", plan, kafka_bootstrap_server_host_port, KAFKA_OUTPUT_TOPIC, KAFKA_SERVICE_NAME)

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


def verify_counts(word, plan, kafka_bootstrap_server_host_port, kafka_output_topic, service_name):
    plan.print("Checking kafka topic for kurtosis count")
    exec_check_data = ExecRecipe(
        command=[
            "/bin/sh",
            "-c",
            "./opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server %s --topic %s --group cli-test" % (
            kafka_bootstrap_server_host_port, kafka_output_topic),
        ],
        extract={
            "word-count": 'select(.word == %s)' % word
        }
    )
    plan.wait(
        service_name=service_name,
        recipe=exec_check_data,
        field="extract.word-count",
        assertion="==",
        target_value="3",
    )

    return


def upload_files(plan):
    base_path = "github.com/kurtosis-tech/awesome-kurtosis/flink-kafka-example/stuff/lib"

    artifact_reference = plan.upload_files(
        src=base_path,
        name="flink-lib-extra-jars",
    )

    return artifact_reference

# def upload_flink_job(plan, flink_job_jar_path, flink_port_id):
#     recipe = PostHttpRequestRecipe(
#         port_id = flink_portid,
#         endpoint = "/jars/upload",
#         content_type = "application/x-java-archive",
#         body = "{\"data\": \"this is sample body for POST\"}",
#         extract = {
#             "extractfield" : ".name.id",
#         },
#     )
#     return recipe

# def upload_flink_job(plan, kafka_bootstrap_server_host_port, kafka_topic):
#     exec_upload_jar = ExecRecipe(
#         command=[
#             "/bin/sh",
#             "-c",
#             "./opt/bitnami/kafka/bin/kafka-console-consumer.sh --bootstrap-server %s --topic %s --partition 0" % (kafka_bootstrap_server_host_port, kafka_topic),
#             ]
#     )
#     plan.print("Checking kafka topic")
#     return
