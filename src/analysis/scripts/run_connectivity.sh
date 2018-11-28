#!/usr/bin/env bash

set -e

export SHELL  # makes 'parallel' stop complaining about $SHELL being unset

cd `dirname $0`
source utils.sh

NB_POSTGRESQL_HOST="${NB_POSTGRESQL_HOST:-127.0.0.1}"
NB_POSTGRESQL_DB="${NB_POSTGRESQL_DB:-pfb}"
NB_POSTGRESQL_USER="${NB_POSTGRESQL_USER:-gis}"
NB_POSTGRESQL_PASSWORD="${NB_POSTGRESQL_PASSWORD:-gis}"
NB_OUTPUT_SRID="${NB_OUTPUT_SRID:-2163}"
NB_MAX_TRIP_DISTANCE="${NB_MAX_TRIP_DISTANCE:-2680}"
TOLERANCE_COLLEGES="${TOLERANCE_COLLEGES:-100}"         # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_COMM_CTR="${TOLERANCE_COMM_CTR:-50}"          # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_DOCTORS="${TOLERANCE_DOCTORS:-50}"            # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_DENTISTS="${TOLERANCE_DENTISTS:-50}"          # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_HOSPITALS="${TOLERANCE_HOSPITALS:-50}"        # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_PHARMACIES="${TOLERANCE_PHARMACIES:-50}"      # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_PARKS="${TOLERANCE_PARKS:-50}"                # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_RETAIL="${TOLERANCE_RETAIL:-50}"              # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_TRANSIT="${TOLERANCE_TRANSIT:-75}"            # cluster tolerance given in units of $NB_OUTPUT_SRID
TOLERANCE_UNIVERSITIES="${TOLERANCE_UNIVERSITIES:-150}" # cluster tolerance given in units of $NB_OUTPUT_SRID
MIN_PATH_LENGTH="${MIN_PATH_LENGTH:-4800}"              # minimum path length to be considered for recreation access
MIN_PATH_BBOX="${MIN_PATH_BBOX:-3300}"                  # minimum corner-to-corner span of path bounding box to be considered for recreation access
BLOCK_ROAD_BUFFER="${BLOCK_ROAD_BUFFER:-15}"            # buffer distance to find roads associated with a block
BLOCK_ROAD_MIN_LENGTH="${BLOCK_ROAD_MIN_LENGTH:-30}"    # minimum length road must overlap with block buffer to be associated
SCORE_TOTAL="${SCORE_TOTAL:-100}"
SCORE_PEOPLE="${SCORE_PEOPLE:-15}"
SCORE_OPPORTUNITY="${SCORE_OPPORTUNITY:-20}"
SCORE_CORESVCS="${SCORE_CORESVCS:-20}"
SCORE_RETAIL="${SCORE_RETAIL:-15}"
SCORE_RECREATION="${SCORE_RECREATION:-15}"
SCORE_TRANSIT="${SCORE_TRANSIT:-15}"

# Limit custom output formatting for `time` command
export TIME="\nTIMING: %C\nTIMING:\t%E elapsed %Kkb mem\n"

update_status "BUILDING" "Building network"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f ../connectivity/build_network.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v block_road_buffer="${BLOCK_ROAD_BUFFER}" \
  -v block_road_min_length="${BLOCK_ROAD_MIN_LENGTH}" \
  -f ../connectivity/census_blocks.sql

update_status "CONNECTIVITY" "Reachable roads high stress"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -f ../connectivity/reachable_roads_high_stress_prep.sql

/usr/bin/time parallel<<EOF
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=0 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=1 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=2 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=3 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=4 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=5 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=6 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=7 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_high_stress_calc.sql
EOF

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -f ../connectivity/reachable_roads_high_stress_cleanup.sql

update_status "CONNECTIVITY" "Reachable roads low stress"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -f ../connectivity/reachable_roads_low_stress_prep.sql

/usr/bin/time parallel<<EOF
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=0 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=1 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=2 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=3 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=4 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=5 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=6 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" -v thread_num=8 -v thread_no=7 -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" -f ../connectivity/reachable_roads_low_stress_calc.sql
EOF

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -f ../connectivity/reachable_roads_low_stress_cleanup.sql

update_status "CONNECTIVITY" "Connected census blocks"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_max_trip_distance="${NB_MAX_TRIP_DISTANCE}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f ../connectivity/connected_census_blocks.sql

update_status "METRICS" "Access: population"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v max_score=1 \
  -v step1=0.03 \
  -v score1=0.1 \
  -v step2=0.2 \
  -v score2=0.4 \
  -v step3=0.5 \
  -v score3=0.8 \
  -f ../connectivity/access_population.sql

update_status "METRICS" "Destinations"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_COLLEGES}" \
  -f ../connectivity/destinations/colleges.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_COMM_CTR}" \
  -f ../connectivity/destinations/community_centers.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_DOCTORS}" \
  -f ../connectivity/destinations/doctors.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_DENTISTS}" \
  -f ../connectivity/destinations/dentists.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_HOSPITALS}" \
  -f ../connectivity/destinations/hospitals.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_PHARMACIES}" \
  -f ../connectivity/destinations/pharmacies.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_PARKS}" \
  -f ../connectivity/destinations/parks.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_RETAIL}" \
  -f ../connectivity/destinations/retail.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f ../connectivity/destinations/schools.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f ../connectivity/destinations/social_services.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -f ../connectivity/destinations/supermarkets.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_TRANSIT}" \
  -f ../connectivity/destinations/transit.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v nb_output_srid="${NB_OUTPUT_SRID}" \
  -v cluster_tolerance="${TOLERANCE_UNIVERSITIES}" \
  -f ../connectivity/destinations/universities.sql

update_status "METRICS" "Access: colleges"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f ../connectivity/access_colleges.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f ../connectivity/access_community_centers.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f ../connectivity/access_doctors.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f ../connectivity/access_dentists.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f ../connectivity/access_hospitals.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f ../connectivity/access_pharmacies.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.3 \
  -v second=0.2 \
  -v third=0.2 \
  -v max_score=1 \
  -f ../connectivity/access_parks.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.4 \
  -v second=0.2 \
  -v third=0.1 \
  -v max_score=1 \
  -f ../connectivity/access_retail.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.3 \
  -v second=0.2 \
  -v third=0.2 \
  -v max_score=1 \
  -f ../connectivity/access_schools.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f ../connectivity/access_social_services.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.6 \
  -v second=0.2 \
  -v third=0 \
  -v max_score=1 \
  -f ../connectivity/access_supermarkets.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.7 \
  -v second=0.2 \
  -v third=0 \
  -v max_score=1 \
  -v min_path_length="${MIN_PATH_LENGTH}" \
  -v min_bbox_length="${MIN_PATH_BBOX}" \
  -f ../connectivity/access_trails.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.6 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f ../connectivity/access_transit.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v first=0.7 \
  -v second=0 \
  -v third=0 \
  -v max_score=1 \
  -f ../connectivity/access_universities.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v total=${SCORE_TOTAL} \
  -v people=${SCORE_PEOPLE} \
  -v opportunity=${SCORE_OPPORTUNITY} \
  -v core_services=${SCORE_CORESVCS} \
  -v retail=${SCORE_RETAIL} \
  -v recreation=${SCORE_RECREATION} \
  -v transit=${SCORE_TRANSIT} \
  -f ../connectivity/access_overall.sql

/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -f ../connectivity/score_inputs.sql

update_status "METRICS" "Overall scores"
/usr/bin/time psql -h "${NB_POSTGRESQL_HOST}" -U "${NB_POSTGRESQL_USER}" -d "${NB_POSTGRESQL_DB}" \
  -v total=${SCORE_TOTAL} \
  -v people=${SCORE_PEOPLE} \
  -v opportunity=${SCORE_OPPORTUNITY} \
  -v core_services=${SCORE_CORESVCS} \
  -v retail=${SCORE_RETAIL} \
  -v recreation=${SCORE_RECREATION} \
  -v transit=${SCORE_TRANSIT} \
  -f ../connectivity/overall_scores.sql
