POSTGRES_SERVICE_NAME="cl-postgres"
POSTGRES_IMAGE="postgres"

PG_USER="postgres"
PG_DATABASE="chainlink_test"
PG_PASSWORD="secretdatabasepassword"
PG_PORT=5432


def spin_up_database(plan):
    postgres_database = plan.add_service(
        name=POSTGRES_SERVICE_NAME,
        config=ServiceConfig(
            image=POSTGRES_IMAGE,
            ports={
                "postgres": PortSpec(number=PG_PORT),
            },
            env_vars={
                "POSTGRES_USER": PG_USER,
                "POSTGRES_DB": PG_DATABASE,
                "POSTGRES_PASSWORD": PG_PASSWORD,
            },
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
