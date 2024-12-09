import pytest
import requests
from time import sleep
from docker.errors import NotFound

def test_odoo_connection(docker_environment):
    """Test la connexion à Odoo"""
    max_retries = 30
    retry_interval = 2
    
    for _ in range(max_retries):
        try:
            response = requests.get("http://localhost:8069")
            if response.status_code == 200:
                break
        except requests.exceptions.ConnectionError:
            sleep(retry_interval)
    else:
        pytest.fail("Impossible de se connecter à Odoo après plusieurs tentatives")

def test_database_connection(docker_environment):
    """Test la connexion à la base de données"""
    import psycopg2
    try:
        conn = psycopg2.connect(
            dbname="test_db",
            user="test_user",
            password="test_password",
            host="localhost"
        )
        assert conn.status == psycopg2.extensions.STATUS_READY
        conn.close()
    except Exception as e:
        pytest.fail(f"Échec de la connexion à la base de données: {str(e)}")

def test_container_health(docker_environment):
    """Vérifie l'état de santé des conteneurs"""
    client = docker.from_env()
    
    containers = {
        "test_db": "postgres:13",
        "test_odoo": "odoo:13.0"
    }
    
    for name, image in containers.items():
        try:
            container = client.containers.get(name)
            assert container.status == "running"
            assert container.image.tags[0].startswith(image)
        except NotFound:
            pytest.fail(f"Conteneur {name} non trouvé")

def test_network_connectivity(docker_environment):
    """Test la connectivité réseau entre les conteneurs"""
    client = docker.from_env()
    
    try:
        network = client.networks.get("test_network")
        containers = network.containers
        assert len(containers) >= 2
        
        # Vérifie que tous les conteneurs sont connectés
        container_names = [c.name for c in containers]
        assert "test_db" in container_names
        assert "test_odoo" in container_names
    except Exception as e:
        pytest.fail(f"Erreur de connectivité réseau: {str(e)}")
