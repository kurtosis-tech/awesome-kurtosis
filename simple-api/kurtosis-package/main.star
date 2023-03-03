# For more information on how to use Starlark with Kurtosis please see: https://docs.kurtosis.com/explanations/starlark/
PACKAGE_NAME = "simple-api"
KURTOSIS_API_PORT = 8080
KURTOSIS_API_SERVICE_NAME = "kurtosis-simple-api"
KURTOSIS_API_IMAGE_NAME = "kurtosistech/kurtosis-simple-api"
KURTOSIS_API_PORT_NAME = "http"


def run(plan):
    plan.print("Starting the " + PACKAGE_NAME + " package")

    kurtosis_api_service = plan.add_service(
        service_name = KURTOSIS_API_SERVICE_NAME,
        config = ServiceConfig(
            image = KURTOSIS_API_IMAGE_NAME,
            ports = {
                "http": PortSpec(
                    number = KURTOSIS_API_PORT,
                    application_protocol = KURTOSIS_API_PORT_NAME,
                ),
            },
        ),
    )

    # Wait till the service becomes healthy
    get_health_recipe = GetHttpRequestRecipe(
        service_name = KURTOSIS_API_SERVICE_NAME,
        port_id = KURTOSIS_API_PORT_NAME,
        endpoint = "/health",
    )
    plan.wait(get_health_recipe, "code", "IN", [200], timeout="30s")

    return
