#!/bin/bash

set -e

export NB_POSTGRESQL_HOST="${NB_POSTGRESQL_HOST:-localhost}"
export NB_POSTGRESQL_DB="${NB_POSTGRESQL_DB:-pfb}"
export NB_POSTGRESQL_USER="${NB_POSTGRESQL_USER:-gis}"
export PGPASSWORD="${NB_POSTGRESQL_PASSWORD:-gis}"

source "$(dirname $0)"/utils.sh

# start postgres and capture the PID
/docker-entrypoint.sh postgres | tee /tmp/postgres_stdout.txt &
POSTGRES_PROC=$!

MAX_TRIES=30
counter=1

# wait for database to become available
while true
do
    echo waiting for database, try ${counter}
    sleep 3
    # don't check if postgres is up until docker-entrypoint gives us the signal
    if grep 'PostgreSQL init process complete' /tmp/postgres_stdout.txt > /dev/null
    then
        set +e
        psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
            -c "SELECT 1" &> /dev/null
        postgresql_status=$?
        set -e
        if [ "$postgresql_status" == "0" ]
        then
            break
        fi
    fi
    if [ "$counter" == "$MAX_TRIES" ]; then
        echo database did not come up successfully
        kill $POSTGRES_PROC
        exit 1
    fi
    ((counter++))
done

set +e
/opt/pfb/analysis/scripts/run_analysis.sh
PFB_EXIT_STATUS=$?
set -e

if [ $PFB_EXIT_STATUS -eq  0 ]; then
    update_status "COMPLETE" "Finished analysis"
else
    update_status "ERROR" "Failed" "See job logs for more details."
fi

# This will exit immediately when there's no pseudo-TTY but provide a shell if there is,
# so it enables keeping a docker container alive after processing by running it with `-t`
bash

# shutdown postgres
su postgres -c "/usr/lib/postgresql/9.6/bin/pg_ctl stop"
wait

exit $PFB_EXIT_STATUS
