#!/usr/bin/env bash

# ec prefix stands for 'export connectivity'

set -e

cd $(dirname "$0")
source ./utils.sh

NB_POSTGRESQL_HOST="${NB_POSTGRESQL_HOST:-127.0.0.1}"
NB_POSTGRESQL_DB="${NB_POSTGRESQL_DB:-pfb}"
NB_POSTGRESQL_USER="${NB_POSTGRESQL_USER:-gis}"
NB_POSTGRESQL_PASSWORD="${NB_POSTGRESQL_PASSWORD:-gis}"
NB_POSTGRESQL_PORT="${NB_POSTGRESQL_PORT:-5432}"

function ec_usage() {
    echo -n \
"
Usage: $(basename "$0") <local_directory>

Export data from a successful run of the PeopleForBikes Network Analysis.
Writes to <local_directory>, if AWS_STORAGE_BUCKET_NAME + PFB_S3_RESULTS_PATH is set,
uploads to S3 at {AWS_STORAGE_BUCKET_NAME}/{PFB_S3_RESULTS_PATH}.

<local_directory> must be an absolute path (pgsql COPY doesn't support relative paths)

This script exports the following tables:
 - neighborhood_ways as SHP
 - neighborhood_ways as GeoJSON (TODO)
 - neighborhood_connected_census_blocks as SHP (currently disabled)
 - neighborhood_score_inputs as CSV
 - neighborhood_overall_scores as CSV

Optional ENV vars:

AWS_STORAGE_BUCKET_NAME
AWS_PROFILE (necessary for using S3 in local development)
PFB_S3_RESULTS_PATH

NB_POSTGRESQL_HOST - Default: 127.0.0.1
NB_POSTGRESQL_DB - Default: pfb
NB_POSTGRESQL_USER - Default: gis
NB_POSTGRESQL_PASSWORD - Default: gis
NB_POSTGRESQL_PORT - Default: 5432

"
}

function ec_export_table_shp() {
    OUTPUT_DIR="$1"
    EXPORT_TABLENAME="$2"

    psql -h "${NB_POSTGRESQL_HOST}" \
         -U "${NB_POSTGRESQL_USER}" \
         -p "${NB_POSTGRESQL_PORT}" \
         -d "${NB_POSTGRESQL_DB}" \
         -c "ALTER TABLE ${EXPORT_TABLENAME} ADD COLUMN IF NOT EXISTS job_id uuid;"
    if [ -n "${PFB_JOB_ID}" ];
    then
        psql -h "${NB_POSTGRESQL_HOST}" \
            -U "${NB_POSTGRESQL_USER}" \
            -p "${NB_POSTGRESQL_PORT}" \
            -d "${NB_POSTGRESQL_DB}" \
            -c "UPDATE ${EXPORT_TABLENAME} SET job_id = '${PFB_JOB_ID}';"
    fi

    FILENAME="${OUTPUT_DIR}/${EXPORT_TABLENAME}.shp"
    pgsql2shp -h "${NB_POSTGRESQL_HOST}" \
              -u "${NB_POSTGRESQL_USER}" \
              -p "${NB_POSTGRESQL_PORT}" \
              -P "${NB_POSTGRESQL_PASSWORD}" \
              -f "${FILENAME}" \
              "${NB_POSTGRESQL_DB}" \
              "${EXPORT_TABLENAME}"
    pushd "${OUTPUT_DIR}"
    zip "${EXPORT_TABLENAME}.zip" "${EXPORT_TABLENAME}".*
    rm "${EXPORT_TABLENAME}".[^z]*
    popd
}

function ec_export_table_csv() {
    OUTPUT_DIR="$1"
    EXPORT_TABLENAME="$2"

    FILENAME="${OUTPUT_DIR}/${EXPORT_TABLENAME}.csv"
    psql -h "${NB_POSTGRESQL_HOST}" \
         -U "${NB_POSTGRESQL_USER}" \
         -p "${NB_POSTGRESQL_PORT}" \
         -d "${NB_POSTGRESQL_DB}" \
         -c "\COPY ${EXPORT_TABLENAME} TO '${FILENAME}' WITH (FORMAT CSV, HEADER)"
}

function ec_export_table_geojson() {
  OUTPUT_DIR="${1}"
  EXPORT_TABLENAME="${2}"

  FILENAME="${OUTPUT_DIR}/${EXPORT_TABLENAME}.geojson"
  ogr2ogr -f GeoJSON "${FILENAME}" -skipfailures \
          -t_srs EPSG:4326 \
          "PG:host=${NB_POSTGRESQL_HOST} dbname=${NB_POSTGRESQL_DB} user=${NB_POSTGRESQL_USER}" \
          -sql "select * from ${EXPORT_TABLENAME}"
}

function ec_export_destination_geojson() {
  OUTPUT_DIR="${1}"
  EXPORT_TABLENAME="${2}"

  echo "EXPORTING: ${EXPORT_TABLENAME}"
  FILENAME="${OUTPUT_DIR}/${EXPORT_TABLENAME}.geojson"
  # Our version of ogr2ogr isn't new enough to specify the geom column :(
  #   Instead, ogr2ogr states it takes the "last" geom column, so we manually specify
  #   it here to ensure we always take the one we want
  ogr2ogr -f GeoJSON "${FILENAME}" -skipfailures \
          -t_srs EPSG:4326 \
          "PG:host=${NB_POSTGRESQL_HOST} dbname=${NB_POSTGRESQL_DB} user=${NB_POSTGRESQL_USER}" \
          -sql "select * from ${EXPORT_TABLENAME}"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]
then
    if [ "${1}" = "--help" ]
    then
        ec_usage
    elif [ -z "${1}" ]
    then
        ec_usage
        exit 1
    else
        NB_OUTPUT_DIR="${1}"
        OUTPUT_DIR="${NB_OUTPUT_DIR}"
        echo "Exporting analysis to ${OUTPUT_DIR}"
        update_status "EXPORTING" "Exporting results"
        mkdir -p "${OUTPUT_DIR}"

        # Export neighborhood_ways as SHP
        ec_export_table_shp "${OUTPUT_DIR}" "neighborhood_ways"

        # Export census blocks
        ec_export_table_shp "${OUTPUT_DIR}" "neighborhood_census_blocks"
        ec_export_table_geojson "${OUTPUT_DIR}" "neighborhood_census_blocks"

        # Export destinations tables as GeoJSON
        DESTINATION_TABLES='
          neighborhood_colleges
          neighborhood_community_centers
          neighborhood_doctors
          neighborhood_dentists
          neighborhood_hospitals
          neighborhood_pharmacies
          neighborhood_parks
          neighborhood_retail
          neighborhood_schools
          neighborhood_social_services
          neighborhood_supermarkets
          neighborhood_transit
          neighborhood_universities
        '
        for DESTINATION in ${DESTINATION_TABLES}; do
          ec_export_destination_geojson "${OUTPUT_DIR}" "${DESTINATION}"
        done

        # Export neighborhood ways as GeoJSON
        # TODO: Export this once we know we need it

        # Export neighborhood_connected_census_blocks as CSV
        # -9 max compression, -m move file, -j junk paths in zipped archive, -q quiet
        ec_export_table_csv "${OUTPUT_DIR}" "neighborhood_connected_census_blocks"
        zip -jmq9 "${OUTPUT_DIR}/neighborhood_connected_census_blocks.csv.zip" \
                  "${OUTPUT_DIR}/neighborhood_connected_census_blocks.csv"

        # Export neighborhood_score_inputs as CSV
        ec_export_table_csv "${OUTPUT_DIR}" "neighborhood_score_inputs"

        # Export neighborhood_overall_scores as CSV
        ec_export_table_csv "${OUTPUT_DIR}" "neighborhood_overall_scores"
        # Send overall_scores to Django app
        update_overall_scores "${OUTPUT_DIR}/neighborhood_overall_scores.csv"

        if [ -n "${AWS_STORAGE_BUCKET_NAME}" ] && [ -n "${PFB_S3_RESULTS_PATH}" ]
        then
          sync  # Probably superfluous, but the s3 command said "file changed while reading" once
          update_status "EXPORTING" "Uploading results"
          aws s3 cp --quiet --recursive "${OUTPUT_DIR}" \
            "s3://${AWS_STORAGE_BUCKET_NAME}/${PFB_S3_RESULTS_PATH}"
        fi

        # Insert shapefile geometries into Django app DB if we have PFB_JOB_ID
        PFB_S3_STORAGE_BUCKET="${AWS_STORAGE_BUCKET_NAME}" import_geometries_for_job
    fi
fi
