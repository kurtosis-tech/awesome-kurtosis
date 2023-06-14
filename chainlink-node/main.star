avalanche_module = import_module("github.com/kurtosis-tech/avalanche-package/main.star")
eth_network_package = import_module("github.com/kurtosis-tech/eth-network-package/main.star")

postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

CHAINLINK_SERVICE_NAME = "chainlink"
CHAINLINK_IMAGE = "smartcontract/chainlink:1.13.1"
CHAINLINK_PORT = 6688
CHAINLINK_PORT_WAIT = "30s"
CHAINLINK_P2PV2_PORT=8000

# Postgres info
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "secretdatabasepassword"
POSTGRES_DATABASE = "chainlink_test"
POSTGRES_SERVICE_NAME = "postgres"
POSTGRES_URL_MAIN_SEPARATOR = "@"
POSTGRES_URL_HOSTNAME_DBNAME_SEPARATOR = "/"


def run(plan, args):
    # Configure the chain to connect to based on the args
    is_local_chain, chain_name, chain_id, wss_url, http_url = init_chain_connection(plan, args)

    # Spin up the postgres database and wait for it to be up and ready
    postgres_args = {
        "password": POSTGRES_PASSWORD,
        "database": POSTGRES_DATABASE,
        "user": POSTGRES_USER,
        "name": POSTGRES_SERVICE_NAME,
    }

    postgres_db = postgres.run(plan, postgres_args)

    postgres_db_hostname = get_postgres_hostname_from_service(postgres_db)

    # Render the config.toml and secret.toml file necessary to start the Chainlink node
    chainlink_config_files = render_chainlink_config(plan, postgres_db_hostname, postgres_db.port.number, chain_name, chain_id, wss_url, http_url)

    # Seed the database by creating a user programatically
    # In the normal workflow, the user is being created by the user running the
    # container everytime the container starts on a fresh database. Here, we
    # programatically insert the values into the DB to create the user automatically
    seed_database(plan, chainlink_config_files)

    # Finally we can start the Chainlink node and wait for it to be up and running
    chainlink_image_name = CHAINLINK_IMAGE
    mounted_files = {
        "/chainlink/": chainlink_config_files,
    }

    chainlink_service = plan.add_service(
        name=CHAINLINK_SERVICE_NAME,
        config=ServiceConfig(
            image=chainlink_image_name,
            ports={
                "http": PortSpec(number=CHAINLINK_PORT, wait=CHAINLINK_PORT_WAIT),
                # "tcp": PortSpec(number=CHAINLINK_P2PV2_PORT, wait=None)
            },
            files=mounted_files,
            entrypoint=[
                "chainlink"
            ],
            cmd=[
                "-c",
                "/chainlink/config.toml",
                "-s",
                "/chainlink/secret.toml",
                "node",
                "start",
            ],
        )
    )

    plan.wait(
        service_name=chainlink_service.name,
        recipe=GetHttpRequestRecipe(
            port_id="http",
            endpoint="/",
        ),
        field="code",
        assertion="==",
        target_value=200,
        timeout="1m",
    )


def init_chain_connection(plan, args):
    chain_name = args["chain_name"]
    chain_id = args["chain_id"]
    if args["wss_url"] != "" and args["http_url"] != "":
        plan.print("Connecting to remote chain with ID: {}".format(chain_id))
        return False, chain_name, chain_id, args["wss_url"], args["http_url"]
    
    ws_url = ""
    http_url = ""

    if args["chain_id"] == "43112":
        plan.print("Spinning up a local Avalanche chain and connecting to it")
        avalanche_nodes = avalanche_module.run(plan, args)
        random_avax_node = avalanche_nodes[0]
        avax_ip_port = "{}:{}".format(random_avax_node.ip_address, random_avax_node.ports["rpc"].number)
        ws_url = "ws://{}/ext/bc/C/ws".format(avax_ip_port)
        http_url = "http://{}/ext/bc/C/rpc".format(avax_ip_port)
    elif args["chain_id"] == "3151908":
        plan.print("Spinning up local etheruem node")
        participants, _ = eth_network_package.run(plan, args)
        random_eth_node  = participants[0]
        eth_rpc = "{}:{}".format(random_eth_node.el_client_context.ip_addr, random_eth_node.el_client_context.rpc_port_num)
        eth_ws = "{}:{}".format(random_eth_node.el_client_context.ip_addr, random_eth_node.el_client_context.ws_port_num)
        http_url = "http://{}/".format(eth_rpc)
        ws_url = "ws://{}/".format(eth_ws)
    else:
        fail("Got chain_id {} - but no wss_url and http_url provided. Use 43112 for local AVAX or 3151908 for local eth otherwise please specify wss_url and http_url")

    return True, chain_name, chain_id, ws_url, http_url


def render_chainlink_config(plan, postgres_hostname, postgres_port, chain_name, chain_id, wss_url, http_url):
    config_file_template = """
[Log]
Level = 'warn'

[WebServer]
AllowOrigins = '*'
SecureCookies = false

[WebServer.TLS]
HTTPSPort = 0

[[EVM]]
ChainID = '{{.CHAIN_ID}}'

[[EVM.Nodes]]
Name = '{{.NAME}}'
WSURL = '{{.WS_URL}}'
HTTPURL = '{{.HTTP_URL}}'

[Feature]
LogPoller = true

[OCR2]
Enabled = true

[P2P]
[P2P.V2]
Enabled = true
ListenAddresses = ["0.0.0.0:8000"]

[Keeper]
TurnLookBack = 0
"""
    secret_file_template = read_file("github.com/kurtosis-tech/chainlink-starlark/chainlink_resources/secret.toml.tmpl")
    chainlink_config_files = plan.render_templates(
        name="chainlink-configuration",
        config={
            "config.toml": struct(
                template=config_file_template,
                data={
                    "NAME": chain_name,
                    "CHAIN_ID": chain_id,
                    "WS_URL": wss_url,
                    "HTTP_URL": http_url,
                }
            ),
            "secret.toml": struct(
                template=secret_file_template,
                data={
                    "PG_USER": POSTGRES_USER,
                    "PG_PASSWORD": POSTGRES_PASSWORD,
                    "HOST": postgres_hostname,
                    "PORT": postgres_port,
                    "DATABASE": POSTGRES_DATABASE,
                }
            ),
        }
    )
    return chainlink_config_files


def seed_database(plan, chainlink_config_files):
    # This command fails, but at least it seeds the database with the right schema,
    # which is just what we need here
    plan.add_service(
        name="chainlink-seed",
        config=ServiceConfig(
            image=CHAINLINK_IMAGE,
            files={
                "/chainlink/": chainlink_config_files,
            },
            cmd=[
                "-c",
                "/chainlink/config.toml",
                "-s", 
                "/chainlink/secret.toml",
                "node",
                "db",
                "preparetest",
                "--user-only",
            ],
        )
    )

    seed_user_sql = read_file("github.com/kurtosis-tech/chainlink-starlark/chainlink_resources/seed_users.sql")
    psql_command = "psql --username {} -c \"{}\" {}".format(POSTGRES_USER, str(seed_user_sql), POSTGRES_DATABASE)
    create_user_recipe = ExecRecipe(command = ["sh", "-c", psql_command])
    plan.wait(
        service_name=POSTGRES_SERVICE_NAME,
        recipe=create_user_recipe,
        field="code",
        assertion="==",
        target_value=0,
        timeout="20s",
    )

def get_postgres_hostname_from_service(postgres_service):
    postgres_db_url_parts = postgres_service.url.split(POSTGRES_URL_MAIN_SEPARATOR)
    postgres_db_hostname_dbname = postgres_db_url_parts[1].split(POSTGRES_URL_HOSTNAME_DBNAME_SEPARATOR)
    postgres_db_hostname = postgres_db_hostname_dbname[0]
    return postgres_db_hostname
