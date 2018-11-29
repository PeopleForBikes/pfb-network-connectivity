#!/usr/bin/env bash

set -e

cd `dirname $0`
source ../scripts/utils.sh


NB_POSTGRESQL_HOST="${NB_POSTGRESQL_HOST:-127.0.0.1}"
NB_POSTGRESQL_DB="${NB_POSTGRESQL_DB:-pfb}"
NB_POSTGRESQL_USER="${NB_POSTGRESQL_USER:-gis}"
NB_POSTGRESQL_PASSWORD="${NB_POSTGRESQL_PASSWORD:-gis}"
NB_OUTPUT_SRID="${NB_OUTPUT_SRID:-2163}"
NB_SIGCTL_SEARCH_DIST="${NB_SIGCTL_SEARCH_DIST:-25}"    # max search distance for intersection controls
NB_MAX_TRIP_DISTANCE="${NB_MAX_TRIP_DISTANCE:-2680}"
NB_BOUNDARY_BUFFER="${NB_BOUNDARY_BUFFER:-$NB_MAX_TRIP_DISTANCE}"

# drop old tables
echo 'Dropping old tables'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_ways;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_ways_intersections;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_relations_ways;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_nodes;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_relations;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_way_classes;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_way_tags;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_way_types;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_ways;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_ways_vertices_pgr;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_relations_ways;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_osm_nodes;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_osm_relations;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_osm_way_classes;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_osm_way_tags;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.neighborhood_cycwys_osm_way_types;"

# Get the neighborhood_boundary bbox as extent of trimmed census blocks
BBOX=$(psql -h ${NB_POSTGRESQL_HOST} -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -t -c "select ST_Extent(ST_Transform(geom, 4326)) from neighborhood_census_blocks;" | awk -F '[()]' '{print $2}' | tr " " ",")
echo "CLIPPING OSM TO: ${BBOX}"

OSM_TEMPDIR="${NB_TEMPDIR:-$(mktemp -d)}/import_osm"
mkdir -p "${OSM_TEMPDIR}"

update_status "IMPORTING" "Clipping provided OSM file"
osmconvert "${1}" \
  --drop-broken-refs \
  -b="${BBOX}" \
  -o="${OSM_TEMPDIR}/converted.osm"
OSM_DATA_FILE="${OSM_TEMPDIR}/converted.osm"

# import the osm with highways
update_status "IMPORTING" "Importing OSM data"
osm2pgrouting \
  -f $OSM_DATA_FILE \
  -h $NB_POSTGRESQL_HOST \
  --dbname ${NB_POSTGRESQL_DB} \
  --username ${NB_POSTGRESQL_USER} \
  --schema received \
  --prefix neighborhood_ \
  --conf ./mapconfig_highway.xml \
  --clean

# import the osm with cycleways that the above misses (bug in osm2pgrouting)
osm2pgrouting \
  -f $OSM_DATA_FILE \
  -h $NB_POSTGRESQL_HOST \
  --dbname ${NB_POSTGRESQL_DB} \
  --username ${NB_POSTGRESQL_USER} \
  --schema scratch \
  --prefix neighborhood_cycwys_ \
  --conf ./mapconfig_cycleway.xml \
  --clean

# rename a few tables (or drop if not needed)
echo 'Renaming tables'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "ALTER TABLE received.neighborhood_ways_vertices_pgr RENAME TO neighborhood_ways_intersections;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "ALTER TABLE received.neighborhood_ways_intersections RENAME CONSTRAINT vertex_id TO neighborhood_vertex_id;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.osm_nodes;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.osm_relations CASCADE;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.osm_way_classes CASCADE;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.osm_way_tags CASCADE;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.osm_way_types CASCADE;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "ALTER TABLE scratch.neighborhood_cycwys_ways_vertices_pgr RENAME CONSTRAINT vertex_id TO neighborhood_vertex_id;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.osm_nodes;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.osm_relations CASCADE;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.osm_way_classes CASCADE;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.osm_way_tags CASCADE;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS scratch.osm_way_types CASCADE;"

# import full osm to fill out additional data needs
# not met by osm2pgrouting

# drop old tables
echo 'Dropping old tables'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_full_line;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_full_point;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_full_polygon;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "DROP TABLE IF EXISTS received.neighborhood_osm_full_roads;"

# import
osm2pgsql \
  --host "${NB_POSTGRESQL_HOST}" \
  --username ${NB_POSTGRESQL_USER} \
  --port 5432 \
  --create \
  --database "${NB_POSTGRESQL_DB}" \
  --prefix "neighborhood_osm_full" \
  --proj "${NB_OUTPUT_SRID}" \
  --style ./pfb.style \
  "${OSM_DATA_FILE}"

# Delete downloaded temp OSM data
rm -rf "${OSM_TEMPDIR}"

# move the full osm tables to the received schema
echo 'Moving tables to received schema'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "ALTER TABLE generated.neighborhood_osm_full_line SET SCHEMA received;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "ALTER TABLE generated.neighborhood_osm_full_point SET SCHEMA received;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "ALTER TABLE generated.neighborhood_osm_full_polygon SET SCHEMA received;"
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
  -c "ALTER TABLE generated.neighborhood_osm_full_roads SET SCHEMA received;"

# process tables
echo 'Updating field names'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v nb_output_srid="${NB_OUTPUT_SRID}" \
    -f ./prepare_tables.sql
echo 'Clipping OSM source data to boundary + buffer'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v nb_boundary_buffer="${NB_BOUNDARY_BUFFER}" \
    -f ./clip_osm.sql
echo 'Removing paths that prohibit bicycles'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
-c "DELETE FROM neighborhood_osm_full_line WHERE bicycle='no' and highway='path';"
echo 'Setting values on road segments'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/one_way.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/width_ft.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/functional_class.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v nb_output_srid="${NB_OUTPUT_SRID}" -f ../features/paths.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/speed_limit.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/lanes.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/park.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/bike_infra.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/class_adjustments.sql
echo 'Setting values on intersections'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../features/legs.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/signalized.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/stops.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/rrfb.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v sigctl_search_dist="${NB_SIGCTL_SEARCH_DIST}" -f ../features/island.sql
echo 'Calculating stress'
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_motorway-trunk.sql
# primary
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v class=primary -v default_speed=40 -v default_lanes=2 \
    -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
    -f ../stress/stress_segments_higher_order.sql
# secondary
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v class=secondary -v default_speed=40 -v default_lanes=2 \
    -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
    -f ../stress/stress_segments_higher_order.sql
# tertiary
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v class=tertiary -v default_speed=30 -v default_lanes=1 \
    -v default_parking=1 -v default_parking_width=8 -v default_facility_width=5 \
    -f ../stress/stress_segments_higher_order.sql
# residential
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v class=residential -v default_speed=25 -v default_lanes=1 \
    -v default_parking=1 -v default_roadway_width=27 \
    -f ../stress/stress_segments_lower_order.sql
# unclassified
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v class=unclassified -v default_speed=25 -v default_lanes=1 \
    -v default_parking=1 -v default_roadway_width=27 \
    -f ../stress/stress_segments_lower_order.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_living_street.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_track.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_path.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_one_way_reset.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_motorway-trunk_ints.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_primary_ints.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_secondary_ints.sql
# tertiary intersections
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v primary_speed=40 \
    -v secondary_speed=40 \
    -v primary_lanes=2 \
    -v secondary_lanes=2 \
    -f ../stress/stress_tertiary_ints.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} \
    -v primary_speed=40 \
    -v secondary_speed=40 \
    -v tertiary_speed=30 \
    -v primary_lanes=2 \
    -v secondary_lanes=2 \
    -v tertiary_lanes=1 \
    -f ../stress/stress_lesser_ints.sql
psql -h $NB_POSTGRESQL_HOST -U ${NB_POSTGRESQL_USER} -d ${NB_POSTGRESQL_DB} -f ../stress/stress_link_ints.sql
