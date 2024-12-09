import pytest
import docker
import os
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['ODOO_URL'] = 'http://odoo.test.local'
    app.config['PGADMIN_URL'] = 'http://pgadmin.test.local'
    with app.test_client() as client:
        yield client

@pytest.fixture(scope="session")
def docker_environment():
    client = docker.from_env()
    network = client.networks.create(
        "test_network",
        driver="bridge"
    )
    
    containers = []
    try:
        # Démarrage de la base de données
        db = client.containers.run(
            "postgres:13",
            environment={
                "POSTGRES_USER": "test_user",
                "POSTGRES_PASSWORD": "test_password",
                "POSTGRES_DB": "test_db"
            },
            network="test_network",
            name="test_db",
            detach=True
        )
        containers.append(db)

        # Démarrage d'Odoo
        odoo = client.containers.run(
            "odoo:13.0",
            environment={
                "HOST": "test_db",
                "USER": "test_user",
                "PASSWORD": "test_password"
            },
            network="test_network",
            name="test_odoo",
            ports={'8069/tcp': 8069},
            detach=True
        )
        containers.append(odoo)

        yield containers

    finally:
        for container in containers:
            container.stop()
            container.remove()
        network.remove()

@pytest.fixture
def app_config():
    return {
        'TESTING': True,
        'DEBUG': False,
        'ODOO_URL': os.getenv('ODOO_URL', 'http://odoo.test.local'),
        'PGADMIN_URL': os.getenv('PGADMIN_URL', 'http://pgadmin.test.local')
    }
