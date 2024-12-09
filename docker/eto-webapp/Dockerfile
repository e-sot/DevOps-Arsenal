# Utiliser une version spécifique de Python pour la stabilité
FROM python:3.9.18-slim-bullseye

# Définir les variables d'environnement
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    APP_HOME=/app \
    POETRY_VERSION=1.4.2 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_CREATE=false

# Définir le répertoire de travail
WORKDIR $APP_HOME

# Installation des dépendances système
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir poetry==$POETRY_VERSION

# Copier les fichiers de dépendances
COPY pyproject.toml poetry.lock ./
COPY requirements.txt .

# Installation des dépendances Python
RUN poetry install --no-dev --no-interaction --no-ansi \
    && pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY . .

# Créer un utilisateur non-root
RUN useradd -m -s /bin/bash appuser \
    && chown -R appuser:appuser $APP_HOME \
    && chmod +x healthcheck.sh

# Basculer vers l'utilisateur non-root
USER appuser

# Configuration du healthcheck
HEALTHCHECK --interval=30s \
            --timeout=30s \
            --start-period=5s \
            --retries=3 \
            CMD ./healthcheck.sh

# Exposer le port
EXPOSE $PORT

# Commande de démarrage
CMD ["python", "app.py"]
