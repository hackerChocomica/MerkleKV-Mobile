def run(plan, args={}):
    """
    Deploy MerkleKV Admin Dashboard with full stack architecture
    """
    
    # Configuration
    config = struct(
        postgres_password = "merklekv_secure_password",
        jwt_secret = "merklekv_jwt_secret_key",
        api_port = 3001,
        frontend_port = 3000,
        postgres_port = 5432,
        redis_port = 6379,
        mqtt_port = 1883
    )
    
    plan.print("🚀 Deploying MerkleKV Admin Dashboard Stack...")
    
    # PostgreSQL Database
    postgres_service = plan.add_service(
        name = "postgres",
        config = ServiceConfig(
            image = "postgres:15-alpine",
            ports = {
                "postgres": PortSpec(
                    number = config.postgres_port,
                    transport_protocol = "TCP"
                )
            },
            env_vars = {
                "POSTGRES_DB": "merklekv",
                "POSTGRES_USER": "merklekv", 
                "POSTGRES_PASSWORD": config.postgres_password,
                "PGDATA": "/var/lib/postgresql/data/pgdata"
            },
            files = {
                "/docker-entrypoint-initdb.d/": "github.com/ai-decenter/MerkleKV-Mobile/admin-dashboard/database/"
            }
        )
    )
    
    # Redis Cache
    redis_service = plan.add_service(
        name = "redis",
        config = ServiceConfig(
            image = "redis:7-alpine",
            ports = {
                "redis": PortSpec(
                    number = config.redis_port,
                    transport_protocol = "TCP"
                )
            },
            cmd = ["redis-server", "--appendonly", "yes"]
        )
    )
    
    # MQTT Broker
    mqtt_service = plan.add_service(
        name = "mqtt-broker",
        config = ServiceConfig(
            image = "eclipse-mosquitto:2.0",
            ports = {
                "mqtt": PortSpec(
                    number = config.mqtt_port,
                    transport_protocol = "TCP"
                ),
                "websocket": PortSpec(
                    number = 9001,
                    transport_protocol = "TCP"
                )
            },
            files = {
                "/mosquitto/config/": "github.com/ai-decenter/MerkleKV-Mobile/broker/mosquitto/config/"
            }
        )
    )
    
    # API Server
    api_service = plan.add_service(
        name = "api-server",
        config = ServiceConfig(
            image = "merklekv/api-server:latest",
            ports = {
                "api": PortSpec(
                    number = config.api_port,
                    transport_protocol = "TCP"
                )
            },
            env_vars = {
                "NODE_ENV": "production",
                "PORT": str(config.api_port),
                "JWT_SECRET": config.jwt_secret,
                "POSTGRES_HOST": postgres_service.hostname,
                "POSTGRES_PORT": str(config.postgres_port),
                "POSTGRES_DB": "merklekv",
                "POSTGRES_USER": "merklekv",
                "POSTGRES_PASSWORD": config.postgres_password,
                "REDIS_HOST": redis_service.hostname,
                "REDIS_PORT": str(config.redis_port),
                "MQTT_HOST": mqtt_service.hostname,
                "MQTT_PORT": str(config.mqtt_port)
            }
        )
    )
    
    # Frontend
    frontend_service = plan.add_service(
        name = "frontend",
        config = ServiceConfig(
            image = "merklekv/admin-frontend:latest",
            ports = {
                "http": PortSpec(
                    number = 80,
                    transport_protocol = "TCP"
                )
            },
            env_vars = {
                "REACT_APP_API_URL": "http://{}:{}".format(
                    api_service.hostname, 
                    config.api_port
                )
            }
        )
    )
    
    # Wait for services to be ready
    plan.wait(
        service_name = "postgres",
        recipe = PostgresReadyCondition(
            port_id = "postgres",
            expected_response = "",
            timeout = "30s"
        ),
        field = "exec",
        assertion = "==",
        target_value = 0,
        timeout = "60s"
    )
    
    # Display access information
    plan.print("✅ MerkleKV Admin Dashboard deployed successfully!")
    plan.print("")
    plan.print("🌐 Frontend: http://{}:{}".format(
        frontend_service.hostname, 
        80
    ))
    plan.print("🔧 API Server: http://{}:{}".format(
        api_service.hostname, 
        config.api_port
    ))
    plan.print("🗄️  PostgreSQL: {}:{}".format(
        postgres_service.hostname, 
        config.postgres_port
    ))
    plan.print("🚀 Redis: {}:{}".format(
        redis_service.hostname, 
        config.redis_port
    ))
    plan.print("📡 MQTT: {}:{}".format(
        mqtt_service.hostname, 
        config.mqtt_port
    ))
    plan.print("")
    plan.print("🔐 Login credentials:")
    plan.print("   Email: admin@merklekv.com")
    plan.print("   Password: admin123")
    
    return struct(
        frontend_url = "http://{}:{}".format(frontend_service.hostname, 80),
        api_url = "http://{}:{}".format(api_service.hostname, config.api_port),
        postgres_connection = "postgresql://merklekv:{}@{}:{}/merklekv".format(
            config.postgres_password,
            postgres_service.hostname,
            config.postgres_port
        )
    )