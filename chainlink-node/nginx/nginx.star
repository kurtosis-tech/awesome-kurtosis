NGINX_SERVICE_NAME="nginx"
NGINX_IMAGE="nginx"
HTTP_PORT=80
HTTPS_PORT=443


def spin_up_nginx(plan, avax_node):
    nginx_cert_artifact, nginx_key_artifact = generate_certificates(plan)
    nginx_conf_template = read_file("github.com/kurtosis-tech/chainlink-starlark/nginx/nginx.conf.tmpl")

    nginx_conf_data = {
        "AVAX_NODE_IP": avax_node.ip_address,
        "AVAX_NODE_PORT": avax_node.ports["rpc"].number
    }
    nginx_config_file_artifact = plan.render_templates(
        name = "nginx-configuration",
        config = {
            "default.conf": struct(
                template = nginx_conf_template,
                data = nginx_conf_data,
            )
        },
    )
    nginx = plan.add_service(
        name=NGINX_SERVICE_NAME,
        config=ServiceConfig(
            image=NGINX_IMAGE,
            ports={
                "http": PortSpec(HTTP_PORT),
                "https": PortSpec(HTTPS_PORT),
            },
            files = {
                "/ssl/cert/": nginx_cert_artifact,
                "/ssl/key/": nginx_key_artifact,
                "/etc/nginx/conf.d": nginx_config_file_artifact,
            }
        )
    )
    plan.wait(
        service_name=nginx.name,
        recipe=GetHttpRequestRecipe(
            port_id="http",
            endpoint="/",
        ),
        field="code",
        assertion="==",
        target_value=200,
        timeout="1m",
    )
    return nginx, nginx_cert_artifact

def generate_certificates(plan):
    # We use an nginx container to generate the certs, as it has openssl pre-installed. 
    # we could use something else
    service_name = "certificate-generator"
    nginx = plan.add_service(
        name=service_name,
        config=ServiceConfig(
            image=NGINX_IMAGE,
        )
    )
    key_file_path = "/home/nginx.key"
    cert_file_path = "/home/nginx.crt"
    plan.exec(
        service_name=service_name,
        recipe=ExecRecipe(
            command=[
                "openssl",
                "req",
                "-x509",
                "-sha256",
                "-nodes",
                "-addext",
                # IMPORTANT: set to the hostname of the NGINX - Kurtosis set hostname to service name 
                # when running on a Docker backend
                "subjectAltName = DNS:{}".format(NGINX_SERVICE_NAME), 
                "-subj",
                # Same as above, Common Name (CN) shoud be set to service name such that it
                # matched the hostname of the future NGINX container in Kurtosis
                "/C=US/O={}/CN={}".format("Kurtosis", NGINX_SERVICE_NAME),
                "-days",
                "365", # Certificate valid for one year
                "-newkey",
                "rsa:2048",
                "-keyout",
                key_file_path,
                "-out",
                cert_file_path,
            ]
        )
    )
    # we store those files in 2 different artifacts because only the certificate need to
    # be shared with the Chainlink node to be trusted. The key should remain in NGINX only 
    nginx_key = plan.store_service_files(
        service_name=service_name,
        src=key_file_path,
        name="nginx-cert-key",
    )
    nginx_cert = plan.store_service_files(
        service_name=service_name,
        src=cert_file_path,
        name="nginx-cert",
    )
    plan.remove_service(name=service_name)
    return nginx_cert, nginx_key
