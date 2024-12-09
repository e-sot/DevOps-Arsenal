from flask import Flask, render_template, jsonify, request
from prometheus_flask_exporter import PrometheusMetrics
from healthcheck import HealthCheck
from datetime import datetime
import logging.config
import os
import redis
import psycopg2
from dotenv import load_dotenv

# Chargement des variables d'environnement
load_dotenv()

# Configuration du logging
logging.config.dictConfig({
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {
            'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        },
    },
    'handlers': {
        'default': {
            'level': 'INFO',
            'formatter': 'standard',
            'class': 'logging.StreamHandler',
        },
    },
    'root': {
        'handlers': ['default'],
        'level': 'INFO',
    }
})

logger = logging.getLogger(__name__)

# Initialisation de l'application
app = Flask(__name__)
metrics = PrometheusMetrics(app)
health = HealthCheck()

# Configuration
app.config.update(
    ODOO_URL=os.getenv('ODOO_URL', 'http://localhost:8069'),
    PGADMIN_URL=os.getenv('PGADMIN_URL', 'http://localhost:5050'),
    REDIS_URL=os.getenv('REDIS_URL', 'redis://localhost:6379/0'),
    DB_HOST=os.getenv('DB_HOST', 'localhost'),
    DB_PORT=os.getenv('DB_PORT', '5432'),
    DB_NAME=os.getenv('DB_NAME', 'postgres'),
    DB_USER=os.getenv('DB_USER', 'postgres'),
    DB_PASSWORD=os.getenv('DB_PASSWORD')
)

# Vérifications de santé
def redis_available():
    try:
        client = redis.from_url(app.config['REDIS_URL'])
        client.ping()
        return True, "Redis connection OK"
    except Exception as e:
        logger.error(f"Redis connection failed: {str(e)}")
        return False, str(e)

def postgres_available():
    try:
        conn = psycopg2.connect(
            host=app.config['DB_HOST'],
            port=app.config['DB_PORT'],
            dbname=app.config['DB_NAME'],
            user=app.config['DB_USER'],
            password=app.config['DB_PASSWORD']
        )
        conn.close()
        return True, "Database connection OK"
    except Exception as e:
        logger.error(f"Database connection failed: {str(e)}")
        return False, str(e)

health.add_check(redis_available)
health.add_check(postgres_available)

# Routes
@app.route('/')
@metrics.counter('home_requests_total', 'Number of requests to home page')
def home():
    try:
        logger.info("Accessing home page")
        return render_template('index.html',
                             odoo_url=app.config['ODOO_URL'],
                             pgadmin_url=app.config['PGADMIN_URL'])
    except Exception as e:
        logger.error(f"Error rendering home page: {str(e)}")
        return jsonify({
            "error": "Internal Server Error",
            "message": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/healthcheck')
def healthcheck():
    return health.run()

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
