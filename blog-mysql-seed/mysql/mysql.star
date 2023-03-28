MYSQL_IMAGE = "mysql:8.0.32"

def create_database(plan, database_name, database_user, database_password, seed_script_artifacts = []):
    files = {}
    for index, artifact in enumerate(seed_script_artifacts):
        files["/docker-entrypoint-initdb.d/{}.sql".format(index)] = artifact
    service_name = "mysql-{}".format(database_name)
    mysql_service = plan.add_service(
        service_name = service_name,
        config = ServiceConfig(
            image = MYSQL_IMAGE,
            ports = {
                "db": PortSpec(
                    number = 8080,
                    transport_protocol = "TCP",
                    application_protocol = "http",
                ),
            },
            files = files,
            env_vars = {
                "MYSQL_ROOT_PASSWORD": "root",
                "MYSQL_DATABASE": database_name,
                "MYSQL_USER": database_user,
                "MYSQL_PASSWORD":  database_password,
            },
        )
    )
    # Wait for MySQL to become available
    mysql_flags = ["-u", database_user, "-p{}".format(database_password), database_name]
    plan.wait(
        service_name = service_name,
        recipe = ExecRecipe(command = ["mysql"] + mysql_flags),
        field = "code",
        assertion = "==",
        target_value = 0,
        timeout = "30s",
    )
    return struct(
        service=mysql_service,
        name=database_name,
        user=database_user,
        password=database_password,
    )


def run_sql(plan, database, sql_query):
    mysql_flags = "-u {} -p{} -e '{}' {}".format(database.user, database.password, sql_query, database.name)
    return plan.exec(
        service_name = database.service.name,
        recipe = ExecRecipe(command = ["sh", "-c", "mysql {}".format(mysql_flags)]),
    )["output"]