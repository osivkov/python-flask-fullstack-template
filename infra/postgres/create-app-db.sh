#!/bin/sh
# Runs only when PostgreSQL initializes an empty data volume.
# Creates the application's non-superuser role and its database, not tables.
set -eu

app_password=$(cat "$APP_DB_PASSWORD_FILE")

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  --set=app_user="$APP_DB_USER" --set=app_password="$app_password" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'app_user') \gexec
SQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  --set=app_user="$APP_DB_USER" --set=app_db="$APP_DB_NAME" <<'SQL'
SELECT format('CREATE DATABASE %I OWNER %I', :'app_db', :'app_user')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'app_db') \gexec
SQL
