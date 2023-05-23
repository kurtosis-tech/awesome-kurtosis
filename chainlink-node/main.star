avalanche_module = import_module("github.com/kurtosis-tech/avalanche-package/main.star")

postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
nginx_helpers = import_module("github.com/kurtosis-tech/chainlink-starlark/nginx/nginx.star")

CHAINLINK_SERVICE_NAME = "chainlink"
# The reason we need a custom docker image is for when the package in run on a local ETH chain
#      When running a local Ethereum network, Chainlink needs the GETH node to run HTTPS endpoint. 
#      We do that by putting the node behind NGINX with self-signed certificates. But then the 
#      Chainlink node needs to trust the self-signed certificate. This is done by adding the certificate
#      to Linux truststore, and running `update-ca-certificates` command. BUT, on the regular Chainlink
#      Docker image, the default `chainlink` user does not have root access, and therefore cannot update
#      the truststore. This image fixes this as well.
# See the README.md for more info
CHAINLINK_IMAGE = "smartcontract/chainlink:1.13.1"
CHAINLINK_CUSTOM_IMAGE = "gbouv/chainlink:1.13.1"
CHAINLINK_PORT = 6688
CHAINLINK_PORT_WAIT = "30s"

# Postgres info
POSTGRES_USER = "postgres"
POSTGRES_PASSWORD = "secretdatabasepassword"
POSTGRES_DATABASE = "chainlink_test"
POSTGRES_SERVICE_NAME = "postgres"
POSTGRES_URL_MAIN_SEPARATOR = "@"
POSTGRES_URL_HOSTNAME_DBNAME_SEPARATOR = "/"


def run(plan, args):
    # Configure the chain to connect to based on the args
    is_local_chain, chain_name, chain_id, wss_url, http_url, custom_certificate_maybe = init_chain_connection(plan, args)

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
    if is_local_chain:
        chainlink_image_name = CHAINLINK_CUSTOM_IMAGE
        # Place the NGINX certificate in the folder of trusted certificates.
        # `update-ca-certificates` will then be run (see below) to add this 
        # cert into Linux truststore so that Chainlink can trust the NGINX
        # certificate
        mounted_files["/usr/local/share/ca-certificates/"] = custom_certificate_maybe
    chainlink_service = plan.add_service(
        name=CHAINLINK_SERVICE_NAME,
        config=ServiceConfig(
            image=chainlink_image_name,
            ports={
                "http": PortSpec(number=CHAINLINK_PORT, wait=CHAINLINK_PORT_WAIT)
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
    # this currently fails in the official docker image because the `chainlink` user in the chainlink 
    # container is not authorized to run this command - it gets a permission denied
    if is_local_chain:
        plan.exec(
            service_name=chainlink_service.name,
            recipe=ExecRecipe(
                command=["sh", "-c", "update-ca-certificates"]
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
        return False, chain_name, chain_id, args["wss_url"], args["http_url"], None
    
    plan.print("Spinning up a local Avalanche chain and connecting to it")
    avalanche_nodes = avalanche_module.run(plan, args)
    # Chainlink needs to connect to a single Avax client
    # Here we pick the first one randomly, we could have picked any
    random_avax_node = avalanche_nodes[0]

    # We need to spin up NGINX in front of the ETH node to enable HTTPS, otherwise
    # the Chainlink node will refuse to connect to it
    nginx, nginx_cert = nginx_helpers.spin_up_nginx(plan, random_avax_node)

    # Those path comes from NGINX config
    wss_url = "ws://{}/ext/bc/C/ws".format(nginx.hostname)
    http_url = "http://{}/ext/bc/C/rpc".format(nginx.hostname)
    return True, chain_name, chain_id, wss_url, http_url, nginx_cert


def render_chainlink_config(plan, postgres_hostname, postgres_port, chain_name, chain_id, wss_url, http_url):
    config_file_template = read_file("github.com/kurtosis-tech/chainlink-starlark/chainlink_resources/config.toml.tmpl")
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
