postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")
readyset = import_module("github.com/kurtosis-tech/readyset-package/main.star")

password = "readyset"
database = "test"

#TODO: in next pr will paramtarize this a little, add comments and will update the readme so that I can share in relevant channels hopefully by EOD
def run_local_postgres_and_readyset(plan):
    seed_file_artifact = plan.upload_files(
        src="github.com/kurtosis-tech/awesome-kurtosis/readyset-example/seed/postgres_long.sql",
        name="postgres_seed_file"
    )

    postgres_args = { 
        "postgres_config": ["wal_level=logical"],
        "seed_file_artifact": "postgres_seed_file",
        "password": password,
        "database": database,
    }

    postgres_data = postgres.run( plan, postgres_args)
    return postgres_data

def run_performance_service(plan, readyset_data, postgres_data):
    # this checks whether readyset is ready to cache queries
    # the timeout used is dependent upon the size of the data being snapshotted 
    # through trial and error 1min seems to be reasonable timeout for the seed data thats being used
    snapshot_check_recipe = ExecRecipe(
        command=["sh", "-c", "PGPASSWORD=readyset psql --host=readyset --port=5433 --username=postgres --dbname=readyset -c \"SHOW READYSET TABLES\" | grep Snapshotted | wc -l | awk '{ printf \"%s\", $0 }'"]
    )
   
    plan.wait(service_name="postgres",recipe=snapshot_check_recipe, field="output", assertion="==", target_value="2", timeout="1m")

    python_test_file = plan.upload_files(
        src = "github.com/kurtosis-tech/awesome-kurtosis/readyset-example/app.py",
        name="app"
    )
    
    plan.add_service(
        name = "python-service", 
        config= ServiceConfig(image="python:3.8-slim-buster", files={"/src": "app"})
    )

    # install relevant dependencies
    plan.exec(
        service_name="python-service", 
        recipe=ExecRecipe(
            command=["sh", "-c", "apt-get update && apt-get -y install libpq-dev gcc curl && pip3 install psycopg2 numpy urllib3 tabulate > /dev/null 2>&1"]
        )
    )

    service_executable = "python3 /src/app.py --url {0}"
    postgres_output = plan.exec(
        service_name="python-service",
        recipe=ExecRecipe(
            command=["sh", "-c", service_executable.format(postgres_data.url)]
        )
    )

    cache_recipe = ExecRecipe(
        command=["sh", "-c", "PGPASSWORD=readyset psql --host=readyset --port=5433 --username=postgres --dbname=readyset -c \"CREATE CACHE FROM SELECT count(*) FROM title_ratings JOIN title_basics ON title_ratings.tconst = title_basics.tconst WHERE title_basics.startyear = 2000 AND title_ratings.averagerating > 5;\""]
    )

    plan.exec(service_name="postgres", recipe=cache_recipe)

    readyset_output = plan.exec(
        service_name="python-service",
        recipe=ExecRecipe(
            command=["sh", "-c", service_executable.format(readyset_data.url)]
        )
    )

    return struct(
        postgres_output=postgres_output["output"], 
        readyset_output=readyset_output["output"]
    )

def run(plan, args): 
    # this allows you to hook readyset directly with your cloud database
    
    if args.get("upstream_db_url") != None:
        # readyset package automatically parses the creds from the connection string
        # and connects to the relevant database and snapshots the tables.
        readyset_data = readyset.run(plan, { 
            "upstream_db_url": args["upstream_db_url"]
        })

        ### ADD YOUR CODE
        ### You can add your services here that can use readyset instead of cloud database via readyset connection string which
        ### can be accssed by doing readyset_data["url"]
        return struct(readyset_data=readyset_data)
    

    if args.get("db_type") == "mysql":
        return struct(output="Not Implemented - but we encourage you to give it a try! We already have kurtosis mysql package and you can import the package attach readyset to mysql")
    
    # This is default behaviour to show how kurtosis can simpilfy creating isolated and consistent enviornments with same initial state
    # We can run same set of services under same condition multiple times either locally or on cloud. If you are interested in learning more
    # about cloud offering, please reach out to us. 
    postgres_data = run_local_postgres_and_readyset(plan)
    readyset_data = readyset.run(plan, { 
        "upstream_db_url": postgres_data.url
    })
    
    return run_performance_service(plan, readyset_data, postgres_data)
   