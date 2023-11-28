postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
readyset = import_module("github.com/kurtosis-tech/readyset-package/main.star")

PASSWORD = "readyset"
DATABASE = "test"
USERNAME = "postgres"

DB_TYPE = "db_type"
PYTHON_SERVICE_NAME="benchmark"
UPSTREAM_DB_URL_KEY = "upstream_db_url"

MYSQL_DATABASE_TYPE = "mysql"
BENCHMARK_FILE_LOCATION = "./benchmark.py"
POSTGRES_SEED_FILE_LOCATION = "./seed/postgres_long.sql"
QUERY_TO_CACHE = "CREATE CACHE FROM SELECT count(*) FROM title_ratings JOIN title_basics ON title_ratings.tconst = title_basics.tconst WHERE title_basics.startyear = 2000 AND title_ratings.averagerating > 5;"

def run_local_postgres(plan):
    seed_file_artifact = plan.upload_files(
        src=POSTGRES_SEED_FILE_LOCATION,
        name="postgres_seed_file"
    )

    postgres_data = postgres.run(
        plan,
        user = USERNAME,
        password = PASSWORD,
        database = DATABASE,
        seed_file_artifact_name = "postgres_seed_file",
        extra_configs = ["wal_level=logical"],
    )
    return postgres_data

def run_performance_service(plan, readyset_data, postgres_data):
    # this checks whether readyset is ready to cache queries
    # the timeout used is dependent upon the size of the data being snapshotted 
    # through trial and error 1min seems to be reasonable timeout for the seed data thats being used
    readyset_conn_url = "PGPASSWORD={0} psql --host={1} --port={2} --username={3} --dbname={4}".format(PASSWORD, readyset_data.service.hostname, readyset_data.service.ports["ready_set_port"].number, USERNAME, DATABASE)
    plan.print(readyset_conn_url)

    snapshot_check_recipe = ExecRecipe(
        command=["sh", "-c", readyset_conn_url + " -c \"SHOW READYSET TABLES\" | grep Snapshotted | wc -l |" + " awk '{ printf \"%s\", $0 }'"]
    )
   
    plan.wait(service_name="postgres",recipe=snapshot_check_recipe, field="output", assertion="==", target_value="2", timeout="1m")
    python_test_file = plan.upload_files(
        src = BENCHMARK_FILE_LOCATION,
        name="benchmark"
    )
    
    plan.add_service(
        name = PYTHON_SERVICE_NAME, 
        config= ServiceConfig(image="python:3.8-slim-buster", files={"/src": "benchmark"})
    )

    # install relevant dependencies
    plan.exec(
        service_name=PYTHON_SERVICE_NAME, 
        recipe=ExecRecipe(
            command=["sh", "-c", "apt-get update && apt-get -y install libpq-dev gcc curl && pip3 install psycopg2 numpy urllib3 tabulate"]
        )
    )

    service_executable = "python3 /src/benchmark.py --url {0}"
    postgres_output = plan.exec(
        service_name=PYTHON_SERVICE_NAME,
        recipe=ExecRecipe(
            command=["sh", "-c", service_executable.format(postgres_data.url)]
        )
    )

    cache_recipe = ExecRecipe(
        command=["sh", "-c", "{0} -c \"{1}\" ".format(readyset_conn_url, QUERY_TO_CACHE)]
    )

    plan.wait(service_name="postgres", recipe=cache_recipe, field="code", assertion="==", target_value=0, timeout="30s")

    readyset_output = plan.exec(
        service_name=PYTHON_SERVICE_NAME,
        recipe=ExecRecipe(
            command=["sh", "-c", service_executable.format(readyset_data.url)]
        )
    )

    return struct(
        postgres_output=postgres_output["output"], 
        readyset_output=readyset_output["output"]
    )


def run_local_mysql(plan):
    ### Implement Me for Mysql
    ### This is link to mysql package: https://github.com/kurtosis-tech/mysql-package
    ### A simple mysql example with seed data: https://github.com/kurtosis-tech/awesome-kurtosis/blob/main/blog-mysql-seed/main.star  

    ## you may need to do some post processing so that this method returns url mysql connection string with following schema: `[postgresql|mysql]://<user>:<password>@<hostname>[:<port>]/<database[?<extra_options>]`  
    fail("Not Implemented - but we encourage you to give it a try! We already have kurtosis mysql package and you can import the package attach readyset to mysql")

def run(plan, args): 
    # this allows you to hook readyset directly with your cloud database
    
    if args.get(UPSTREAM_DB_URL_KEY) != None:
        # readyset package automatically parses the creds from the connection string
        # and connects to the relevant database and snapshots the tables.
        readyset_data = readyset.run(plan, { 
            "upstream_db_url": args[UPSTREAM_DB_URL_KEY]
        })

        ### ADD YOUR CODE
        ### You can add your services here that can use readyset with the remote database via readyset connection string which
        ### can be accssed by doing readyset_data.url
        return struct(readyset_data=readyset_data)
    
    if args.get(DB_TYPE) == MYSQL_DATABASE_TYPE:
        mysql_data = run_local_mysql(plan)
        # UNCOMMENT LINES 111 TO 114 ONCE run_local_mysql is implemented
        # readyset_data = readyset.run(plan, {
        #      "upstream_db_url": mysql_data.url
        # })
        # return struct(readyset=readyset_data, mysql=mysql_data)
    
    # This is default behaviour to show how kurtosis can simpilfy creating isolated and consistent environments with same initial state
    # We can run same set of services under same condition multiple times either locally or on cloud. If you are interested in learning more
    # about cloud offering, please reach out to us. 
    postgres_data = run_local_postgres(plan)
    readyset_data = readyset.run( plan, { 
        "upstream_db_url": postgres_data.url
    })
    
    return run_performance_service(plan, readyset_data, postgres_data)
   
