#!/bin/bash

set -e
set -u

function create_user_and_database() {
    local database=$1
    echo "  Creating database '$database'"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
}

if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_user_and_database $db
    done
    echo "Multiple databases created"
fi

# Apply SQL schemas if they exist
if [ -d "/docker-entrypoint-initdb.d/sql" ]; then
    echo "Applying SQL schemas from /docker-entrypoint-initdb.d/sql"

    # Apply suitecrm schema to Member Database (primary CRM)
    if [ -f "/docker-entrypoint-initdb.d/sql/suitecrm-postgres.sql" ]; then
        echo "  Applying suitecrm-postgres.sql to Member Database"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname=membercommons -f /docker-entrypoint-initdb.d/sql/suitecrm-postgres.sql

        echo "  Applying suitecrm-postgres.sql to suitecrm database"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname=suitecrm -f /docker-entrypoint-initdb.d/sql/suitecrm-postgres.sql
    fi

    echo "SQL schemas applied"
fi
