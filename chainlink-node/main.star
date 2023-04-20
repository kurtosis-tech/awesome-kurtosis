eth_network_module = import_module("github.com/kurtosis-tech/eth-network-package/main.star")

IMAGE = "smartcontract/chainlink:1.13.1"

PG_USER="postgres"
PG_DATABASE="chainlink_test"
PG_PASSWORD="secretdatabasepassword"

def run(plan, args):
    # extract the chain ID, WSS and HTTP urls from the args
    chain_id, wss_url, http_url = parse_args(args)

    # Spin up the postgres database and wait for it to be up and ready
    postgres_database = spin_up_database(plan)

    # Render the config.toml and secret.toml file necessary to start the Chainlink node
    chainlink_config_files = render_chainlink_config(plan, postgres_database.ip_address, chain_id, wss_url, http_url)

    # Seed the database by creating a user programatically
    # In the normal workflow, the user is being created by the user running the
    # container everytime the container starts on a fresh database. Here, we
    # programatically insert the values into the DB to create the user automatically
    seed_database(plan, postgres_database.name, chainlink_config_files)

    # Finally we can start the Chainlink node and wait for it to be up and running
    chainlink_service = plan.add_service(
        name="chainlink",
        config=ServiceConfig(
            image=IMAGE,
            ports={
                "http": PortSpec(number=6688)
            },
            files={
                "/chainlink/": chainlink_config_files,
            },
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


def parse_args(args):
    return args["chain_id"], args["wss_url"], args["http_url"]


def spin_up_database(plan):
    seed_users_file = plan.upload_files("github.com/kurtosis-tech/chainlink-starlark/seed_users.sql")
    postgres_database = plan.add_service(
        name="cl-postgres",
        config=ServiceConfig(
            image="postgres",
            ports={
                "postgres": PortSpec(number=5432),
            },
            env_vars={
                "POSTGRES_DB": PG_DATABASE,
                "POSTGRES_PASSWORD": PG_PASSWORD,
            },
            files={
                "/seed-data/": seed_users_file,
            }

        )
    )

    is_ready_command = "pg_isready"
    plan.wait(
        service_name = postgres_database.name,
        recipe = ExecRecipe(command = ["sh", "-c", is_ready_command]),
        field = "code",
        assertion = "==",
        target_value = 0,
        timeout = "30s",
    )
    return postgres_database


def render_chainlink_config(plan, postgres_hostname, chain_id, wss_url, http_url):
    config_file_template = read_file("github.com/kurtosis-tech/chainlink-starlark/config.toml.tmpl")
    secret_file_template = read_file("github.com/kurtosis-tech/chainlink-starlark/secret.toml.tmpl")
    chainlink_config_files = plan.render_templates(
        config={
            "config.toml": struct(
                template=config_file_template,
                data={
                    "NAME": "Sepolia",
                    "CHAIN_ID": chain_id,
                    "WSS_URL": wss_url,
                    "HTTP_URL": http_url,
                }
            ),
            "secret.toml": struct(
                template=secret_file_template,
                data={
                    "PG_USER": PG_USER,
                    "PG_PASSWORD": PG_PASSWORD,
                    "HOST": postgres_hostname,
                    "PORT": 5432, # TODO: pull from the postgres_service object
                    "DATABASE": PG_DATABASE,
                }
            ),
        }
    )
    return chainlink_config_files


def seed_database(plan, postgres_service_name, chainlink_config_files):
    # This command fails, but at least it seeds the database with the right schema,
    # which is just what we need here
    plan.add_service(
        name="chainlink-seed",
        config=ServiceConfig(
            image=IMAGE,
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

    seed_user_sql = read_file("github.com/kurtosis-tech/chainlink-starlark/seed_users.sql")
    create_user_recipe = ExecRecipe(command = ["sh", "-c", "psql --username {} -c \"{}\" {}".format(PG_USER, str(seed_user_sql), PG_DATABASE)])
    plan.wait(
        service_name=postgres_service_name,
        recipe=create_user_recipe,
        field="code",
        assertion="==",
        target_value=0,
        timeout="20s",
    )
