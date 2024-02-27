data_package_module = import_module("github.com/kurtosis-tech/awesome-kurtosis/data-package/main.star")

POSTGRES_PORT_ID = "postgres"
POSTGRES_DB = "app_db"
POSTGRES_USER = "app_user"
POSTGRES_PASSWORD = "password"

SEED_DATA_DIRPATH = "/seed-data"

POSTGREST_PORT_ID = "http"

def run(plan, args):
    # Make data available for use in Kurtosis
    data_package_module_result = data_package_module.run(plan, {})

    # Add a Postgres server
    postgres = plan.add_service(
        name = "postgres",
        config = ServiceConfig(
            image = "postgres:15.2-alpine",
            ports = {
                POSTGRES_PORT_ID: PortSpec(5432, application_protocol = "postgresql"),
            },
            env_vars = {
                "POSTGRES_DB": POSTGRES_DB,
                "POSTGRES_USER": POSTGRES_USER,
                "POSTGRES_PASSWORD": POSTGRES_PASSWORD,
            },
            files = {
                SEED_DATA_DIRPATH: data_package_module_result.files_artifact,
            }
        ),
    )

    # Load the data into Postgres
    postgres_flags = ["-U", POSTGRES_USER,"-d", POSTGRES_DB]
    plan.exec(
        service_name = "postgres",
        recipe = ExecRecipe(command = ["pg_restore"] + postgres_flags + [
            "--no-owner",
            "--role=" + POSTGRES_USER,
            SEED_DATA_DIRPATH + "/" + data_package_module_result.tar_filename,
        ]),
    )

    # Add PostgREST
    postgres_url = "postgresql://{}:{}@{}:{}/{}".format(
        POSTGRES_USER,
        POSTGRES_PASSWORD,
        postgres.hostname,
        postgres.ports[POSTGRES_PORT_ID].number,
        POSTGRES_DB,
    )
    api = plan.add_service(
        name = "api",
        config = ServiceConfig(
            image = "postgrest/postgrest:v10.2.0",
            env_vars = {
                "PGRST_DB_URI": postgres_url,
                "PGRST_DB_ANON_ROLE": POSTGRES_USER,
            },
            ports = {POSTGREST_PORT_ID: PortSpec(3000, application_protocol = "http")},
        )
    )

    # Insert data
    if "actors" in args:
        insert_data(plan, args["actors"])

def insert_data(plan, data):
    plan.request(
        service_name = "api",
        recipe = PostHttpRequestRecipe(
            port_id = POSTGREST_PORT_ID,
            endpoint = "/actor",
            content_type = "application/json",
            body = json.encode(data),
        )
    )
