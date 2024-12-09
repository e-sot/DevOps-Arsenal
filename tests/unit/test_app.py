import pytest
import os
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['ODOO_URL'] = 'http://odoo.test.local'
    app.config['PGADMIN_URL'] = 'http://pgadmin.test.local'
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Test du endpoint healthcheck"""
    response = client.get('/healthcheck')
    assert response.status_code == 200
    assert b'"status": "success"' in response.data

def test_home_page(client):
    """Test de la page d'accueil"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'ETO GROUP - Intranet Applications' in response.data
    assert b'Odoo ERP' in response.data
    assert b'PgAdmin' in response.data

def test_environment_variables():
    """Test des variables d'environnement"""
    test_odoo_url = 'http://test.odoo.local'
    test_pgadmin_url = 'http://test.pgadmin.local'
    
    os.environ['ODOO_URL'] = test_odoo_url
    os.environ['PGADMIN_URL'] = test_pgadmin_url
    
    with app.test_client() as client:
        response = client.get('/')
        assert response.status_code == 200
        assert test_odoo_url.encode() in response.data
        assert test_pgadmin_url.encode() in response.data

def test_error_handling(client):
    """Test de la gestion des erreurs"""
    # Simulation d'une erreur interne
    def mock_render_template(*args, **kwargs):
        raise Exception("Test error")
    
    app.jinja_env.get_template = mock_render_template
    response = client.get('/')
    assert response.status_code == 500
    assert b'"error": "Internal Server Error"' in response.data

def test_static_files(client):
    """Test des fichiers statiques"""
    response = client.get('/')
    assert response.status_code == 200
    assert b'style' in response.data
    assert b'container' in response.data
