ETCD_IMAGE = "softlang/etcd-alpine:v3.4.14"

ETCD_CLIENT_PORT_ID = "client"
ETCD_CLIENT_PORT_NUMBER = 2379
ETCD_CLIENT_PORT_PROTOCOL = "TCP"

ETCD_SERVICE_NAME = "etcd"

def run(plan, args):

    etcd_service_config= ServiceConfig(
        image = ETCD_IMAGE,
        ports = {
            ETCD_CLIENT_PORT_ID: PortSpec(number = ETCD_CLIENT_PORT_NUMBER, transport_protocol = ETCD_CLIENT_PORT_PROTOCOL)
        },
        env_vars = {
            "ALLOW_NONE_AUTHENTICATION": "yes",
            "ETCD_DATA_DIR": "/etcd_data",
            "ETCD_LISTEN_CLIENT_URLS": "http://0.0.0.0:{}".format(ETCD_CLIENT_PORT_NUMBER),
            "ETCD_ADVERTISE_CLIENT_URLS": "http://0.0.0.0:{}".format(ETCD_CLIENT_PORT_NUMBER),
        },
        ready_conditions = ReadyCondition(
            recipe = ExecRecipe(
                command = ["etcdctl", "get", "test"]
            ),
            field = "code",
            assertion = "==",
            target_value = 0
        )
    )

    etcd = plan.add_service(name = ETCD_SERVICE_NAME, config = etcd_service_config)

    return {"service-name": ETCD_SERVICE_NAME, "hostname": etcd.hostname, "port": ETCD_CLIENT_PORT_NUMBER}

