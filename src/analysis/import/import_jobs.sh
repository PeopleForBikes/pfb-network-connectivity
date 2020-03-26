#!/bin/bash

NB_POSTGRESQL_HOST="${NB_POSTGRESQL_HOST:-127.0.0.1}"
NB_POSTGRESQL_DB="${NB_POSTGRESQL_DB:-pfb}"
NB_POSTGRESQL_USER="${NB_POSTGRESQL_USER:-gis}"
NB_POSTGRESQL_PASSWORD="${NB_POSTGRESQL_PASSWORD:-gis}"


set -e

if [[ -n "${PFB_DEBUG}" ]]; then
    set -x
fi

source "$(dirname $0)"/../scripts/utils.sh

function usage() {
    echo -n \
"
Usage: $(basename "$0") <state_abbrev>

Import state jobs data into postgres database.

Requires passing the state FIPS abbrev that the neighborhood boundary is found in. e.g. MA for Massachussetts
    See: https://www.census.gov/geo/reference/ansi_statetables.html

Optional ENV vars:

NB_POSTGRESQL_HOST - Default: 127.0.0.1
NB_POSTGRESQL_DB - Default: pfb
NB_POSTGRESQL_USER - Default: gis
NB_POSTGRESQL_PASSWORD - Default: gis

"
}

function import_job_data() {

    ROOT_TEMPDIR="${NB_TEMPDIR:-$(mktemp -d)}"
    NB_TEMPDIR="${ROOT_TEMPDIR}/import_jobs"
    mkdir -p "${NB_TEMPDIR}"
    # Dir and files must be world readable/executable for postgres to use copy command
    # Must chmod after creating subdir
    chmod -R 775 "${ROOT_TEMPDIR}"

    NB_STATE_ABBREV="${1}"
    NB_DATA_TYPE="${2:-main}"    # Either 'main' or 'aux'
    NB_JOB_FILENAME="${NB_STATE_ABBREV}_od_${NB_DATA_TYPE}_JT00_2017.csv"

    if [ -f "/data/${NB_JOB_FILENAME}.gz" ]; then
        JOB_DOWNLOAD="/data/${NB_JOB_FILENAME}.gz"
    elif [ "${AWS_STORAGE_BUCKET_NAME}" ] && aws s3 ls "s3://${AWS_STORAGE_BUCKET_NAME}/data/${NB_JOB_FILENAME}.gz"; then
        JOB_DOWNLOAD="${NB_TEMPDIR}/${NB_JOB_FILENAME}.gz"
        aws s3 cp "s3://${AWS_STORAGE_BUCKET_NAME}/data/${NB_JOB_FILENAME}.gz" "${JOB_DOWNLOAD}"
    else
        JOB_DOWNLOAD="${NB_TEMPDIR}/${NB_JOB_FILENAME}.gz"
        set +e
        wget -nv -O "${JOB_DOWNLOAD}" "http://lehd.ces.census.gov/data/lodes/LODES7/${NB_STATE_ABBREV}/od/${NB_JOB_FILENAME}.gz"
        WGET_STATUS=$?
        set -e
        if [[ $WGET_STATUS -eq 8 ]]; then
            echo "No 2017 job data available, falling back to 2016 data..."
            JOB_DOWNLOAD="${NB_TEMPDIR}/${NB_JOB_FILENAME}.gz"
            NB_JOB_FILENAME="${NB_STATE_ABBREV}_od_${NB_DATA_TYPE}_JT00_2016.csv"
            wget -nv -O "${JOB_DOWNLOAD}" "http://lehd.ces.census.gov/data/lodes/LODES7/${NB_STATE_ABBREV}/od/${NB_JOB_FILENAME}.gz"
        fi
    fi
    gunzip -c "${JOB_DOWNLOAD}" > "${NB_TEMPDIR}/${NB_JOB_FILENAME}"


    # Import to postgresql
    psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
        -c "
CREATE TABLE IF NOT EXISTS \"state_od_${NB_DATA_TYPE}_JT00\" (
    w_geocode varchar(15),
    h_geocode varchar(15),
    \"S000\" integer,
    \"SA01\" integer,
    \"SA02\" integer,
    \"SA03\" integer,
    \"SE01\" integer,
    \"SE02\" integer,
    \"SE03\" integer,
    \"SI01\" integer,
    \"SI02\" integer,
    \"SI03\" integer,
    createdate VARCHAR(32)
);"
    psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
        -c "TRUNCATE TABLE \"state_od_${NB_DATA_TYPE}_JT00\";"

    # Load data
    psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
        -c "\copy \"state_od_${NB_DATA_TYPE}_JT00\"(w_geocode, h_geocode, \"S000\", \"SA01\", \"SA02\", \"SA03\", \"SE01\", \"SE02\", \"SE03\", \"SI01\", \"SI02\", \"SI03\", createdate) FROM '${NB_TEMPDIR}/${NB_JOB_FILENAME}' DELIMITER ',' CSV HEADER;"

    # Remove NB_TEMPDIR
    rm -rf "${NB_TEMPDIR}"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    if [ "${1:-}" = "--help" ] || [ -z "${1:-}" ]; then
        usage
    else
        NB_STATE_ABBREV="${1,,}"  # force to lower case to match the jobs file download paths

        update_status "IMPORTING" "Importing jobs data"
        import_job_data "${NB_STATE_ABBREV}" "main"
        import_job_data "${NB_STATE_ABBREV}" "aux"
    fi
fi
