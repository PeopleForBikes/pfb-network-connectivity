----------------------------------------
-- INPUTS
-- location: neighborhood
-- proj: :nb_output_srid psql var must be set before running this script,
-- :cluster_tolerance psql var must be set before running this script.
--       e.g. psql -v nb_output_srid=4326 cluster_tolerance=150 -f retail.sql
----------------------------------------
DROP TABLE IF EXISTS generated.neighborhood_retail;

CREATE TABLE generated.neighborhood_retail (
    id SERIAL PRIMARY KEY,
    pop_low_stress INT,
    pop_high_stress INT,
    geom_poly geometry(multipolygon, :nb_output_srid)
);
CREATE INDEX sidx_neighborhood_retail_geomply ON neighborhood_retail USING GIST (geom_poly);

-- insert
INSERT INTO generated.neighborhood_retail (
    geom_poly
)
SELECT  ST_CollectionExtract(unnest(ST_ClusterWithin(way,:cluster_tolerance)),3)
FROM    neighborhood_osm_full_polygon
WHERE   landuse = 'retail';

ANALYZE generated.neighborhood_retail;