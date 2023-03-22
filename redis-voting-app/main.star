main_redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")

VOTING_APP_IMAGE = "mcr.microsoft.com/azuredocs/azure-vote-front:v1"

def run(plan, args):

    plan.print("Spinning up the Redis Package")
    redis_run_output = main_redis_module.run(plan, args)

    redis_hostname = redis_run_output["hostname"]

    plan.add_service(
        service_name = "voting-app",
        config = ServiceConfig(
            ports = {
                "http": PortSpec(number = 80, transport_protocol = "TCP")
            },
            image = VOTING_APP_IMAGE,
            env_vars = {
                "REDIS": redis_service_name,
            }
        )
    )
