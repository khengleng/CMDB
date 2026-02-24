"""
NetBox configuration for Railway.com deployment.
All settings are read from environment variables.
"""
import hashlib
import os
from urllib.parse import unquote, urlparse, urlunparse


def _split_csv(value):
    return [item.strip() for item in value.split(',') if item.strip()]


def _decode_url_component(value):
    return unquote(value) if value else ''


def _with_redis_db(url, db_index):
    parsed = urlparse(url)
    return urlunparse(parsed._replace(path=f'/{db_index}'))


#########################
#   Required settings   #
#########################

ALLOWED_HOSTS = _split_csv(os.environ.get('ALLOWED_HOSTS', 'localhost,127.0.0.1,[::1]'))

# Parse DATABASE_URL from Railway PostgreSQL add-on
# Format: postgresql://user:password@host:port/dbname
DATABASE_URL = os.environ.get('DATABASE_URL', '')
if DATABASE_URL:
    db_url = urlparse(DATABASE_URL)
    DATABASE = {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': db_url.path[1:],  # Remove leading '/'
        'USER': _decode_url_component(db_url.username),
        'PASSWORD': _decode_url_component(db_url.password),
        'HOST': db_url.hostname or 'localhost',
        'PORT': str(db_url.port or 5432),
        'CONN_MAX_AGE': 300,
    }
else:
    DATABASE = {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'netbox'),
        'USER': os.environ.get('DB_USER', 'netbox'),
        'PASSWORD': os.environ.get('DB_PASSWORD', ''),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
        'CONN_MAX_AGE': 300,
    }

# Parse REDIS_URL from Railway Redis add-on
# Format: redis://default:password@host:port
REDIS_URL = os.environ.get('REDIS_URL', '')
if REDIS_URL:
    redis_url = urlparse(REDIS_URL)
    tasks_redis_url = _with_redis_db(REDIS_URL, 0)
    caching_redis_url = _with_redis_db(REDIS_URL, 1)
    redis_host = redis_url.hostname or 'localhost'
    redis_port = redis_url.port or 6379
    redis_password = _decode_url_component(redis_url.password)
    redis_username = _decode_url_component(redis_url.username)
    redis_ssl = redis_url.scheme == 'rediss'

    REDIS = {
        'tasks': {
            'URL': tasks_redis_url,
            'HOST': redis_host,
            'PORT': redis_port,
            'USERNAME': redis_username,
            'PASSWORD': redis_password,
            'DATABASE': 0,
            'SSL': redis_ssl,
        },
        'caching': {
            'URL': caching_redis_url,
            'HOST': redis_host,
            'PORT': redis_port,
            'USERNAME': redis_username,
            'PASSWORD': redis_password,
            'DATABASE': 1,
            'SSL': redis_ssl,
        }
    }
else:
    REDIS = {
        'tasks': {
            'HOST': os.environ.get('REDIS_HOST', 'localhost'),
            'PORT': int(os.environ.get('REDIS_PORT', 6379)),
            'USERNAME': os.environ.get('REDIS_USERNAME', ''),
            'PASSWORD': os.environ.get('REDIS_PASSWORD', ''),
            'DATABASE': 0,
            'SSL': os.environ.get('REDIS_SSL', 'false').lower() == 'true',
        },
        'caching': {
            'HOST': os.environ.get('REDIS_HOST', 'localhost'),
            'PORT': int(os.environ.get('REDIS_PORT', 6379)),
            'USERNAME': os.environ.get('REDIS_USERNAME', ''),
            'PASSWORD': os.environ.get('REDIS_PASSWORD', ''),
            'DATABASE': 1,
            'SSL': os.environ.get('REDIS_SSL', 'false').lower() == 'true',
        }
    }

SECRET_KEY = os.environ.get('SECRET_KEY', '')

# API Token Peppers (required for v2 tokens)
# Derive peppers from SECRET_KEY so they stay stable across restarts.
# NetBox requires each pepper to be >= 50 characters; SHA-256 hex = 64 chars.
if SECRET_KEY:
    _pepper_hash = hashlib.sha256(SECRET_KEY.encode()).hexdigest()  # 64 chars
    API_TOKEN_PEPPERS = {
        1: _pepper_hash,
    }
else:
    API_TOKEN_PEPPERS = {}


#########################
#   Optional settings   #
#########################

# Base URL path (if running behind a reverse proxy at a subpath)
BASE_PATH = os.environ.get('BASE_PATH', '')

CORS_ORIGIN_ALLOW_ALL = os.environ.get('CORS_ORIGIN_ALLOW_ALL', 'false').lower() == 'true'
CORS_ORIGIN_WHITELIST = list(filter(None, os.environ.get('CORS_ORIGIN_WHITELIST', '').split(',')))

CSRF_COOKIE_SECURE = os.environ.get('CSRF_COOKIE_SECURE', 'true').lower() == 'true'
CSRF_TRUSTED_ORIGINS = list(filter(None, os.environ.get('CSRF_TRUSTED_ORIGINS', '').split(',')))

DEBUG = os.environ.get('DEBUG', 'false').lower() == 'true'

DEFAULT_LANGUAGE = os.environ.get('DEFAULT_LANGUAGE', 'en-us')

# Email settings
EMAIL = {
    'SERVER': os.environ.get('EMAIL_SERVER', 'localhost'),
    'PORT': int(os.environ.get('EMAIL_PORT', 25)),
    'USERNAME': os.environ.get('EMAIL_USERNAME', ''),
    'PASSWORD': os.environ.get('EMAIL_PASSWORD', ''),
    'USE_SSL': os.environ.get('EMAIL_USE_SSL', 'false').lower() == 'true',
    'USE_TLS': os.environ.get('EMAIL_USE_TLS', 'false').lower() == 'true',
    'TIMEOUT': int(os.environ.get('EMAIL_TIMEOUT', 10)),
    'FROM_EMAIL': os.environ.get('EMAIL_FROM', ''),
}

LOGIN_REQUIRED = os.environ.get('LOGIN_REQUIRED', 'true').lower() == 'true'
LOGIN_PERSISTENCE = os.environ.get('LOGIN_PERSISTENCE', 'false').lower() == 'true'

METRICS_ENABLED = os.environ.get('METRICS_ENABLED', 'false').lower() == 'true'

# Safety guard for dynamic script execution (extras/scripts & report modules)
# Set true only in trusted environments where script authors are trusted.
ALLOW_UNTRUSTED_SCRIPTS = os.environ.get('ALLOW_UNTRUSTED_SCRIPTS', 'false').lower() == 'true'

# Plugins
PLUGINS = list(filter(None, os.environ.get('PLUGINS', '').split(',')))

SESSION_COOKIE_SECURE = os.environ.get('SESSION_COOKIE_SECURE', 'true').lower() == 'true'

TIME_ZONE = os.environ.get('TIME_ZONE', 'UTC')

# Trust forwarded headers only when explicitly enabled and only behind a trusted proxy.
TRUST_X_FORWARDED_PROTO = os.environ.get('TRUST_X_FORWARDED_PROTO', 'false').lower() == 'true'
TRUST_X_FORWARDED_HOST = os.environ.get('TRUST_X_FORWARDED_HOST', 'false').lower() == 'true'
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https') if TRUST_X_FORWARDED_PROTO else None
USE_X_FORWARDED_HOST = TRUST_X_FORWARDED_HOST
SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', 'false').lower() == 'true'

# Superuser creation from env vars
SUPERUSER_NAME = os.environ.get('SUPERUSER_NAME', '')
SUPERUSER_EMAIL = os.environ.get('SUPERUSER_EMAIL', '')
SUPERUSER_PASSWORD = os.environ.get('SUPERUSER_PASSWORD', '')
