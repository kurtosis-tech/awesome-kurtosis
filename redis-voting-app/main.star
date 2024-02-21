main_redis_module = import_module("github.com/kurtosis-tech/redis-package/main.star")

VOTING_APP_IMAGE = "mcr.microsoft.com/azuredocs/azure-vote-front:v1"

def run(plan, should_party = False):
    """
    Runs a toy app stack containing a voting app with Redis as the backend.

    Args:
        should_party (bool): Whether we'll throw a small party before launching the app!
    """

    if should_party:
        plan.print("Preparing for party...")
        plan.print("It's party time!")

    redis_run_output = main_redis_module.run(plan)
    redis_hostname = redis_run_output.hostname

    plan.add_service(
        name = "voting-app",
        config = ServiceConfig(
            ports = {
                "http": PortSpec(number = 80, transport_protocol = "TCP", application_protocol = "http")
            },
            image = VOTING_APP_IMAGE,
            env_vars = {
                "REDIS": redis_hostname,
            }
        )
    )
