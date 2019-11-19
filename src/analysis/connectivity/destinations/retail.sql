----------------------------------------
-- INPUTS
-- location: neighborhood
-- proj: :nb_output_srid psql var must be set before running this script,
-- :cluster_tolerance psql var must be set before running this script.
--       e.g. psql -v nb_output_srid=2163 cluster_tolerance=50 -f retail.sql
----------------------------------------
DROP TABLE IF EXISTS generated.neighborhood_retail;

CREATE TABLE generated.neighborhood_retail (
    id SERIAL PRIMARY KEY,
    blockid10 CHARACTER VARYING(15)[],
    pop_low_stress INT,
    pop_high_stress INT,
    pop_score FLOAT,
    geom_pt geometry(point, :nb_output_srid),
    geom_poly geometry(multipolygon, :nb_output_srid)
);

-- insert polygons
INSERT INTO generated.neighborhood_retail (
    geom_poly
)
SELECT  ST_Multi(ST_Buffer(ST_CollectionExtract(unnest(ST_ClusterWithin(way,:cluster_tolerance)),3),0))
FROM    neighborhood_osm_full_polygon
WHERE   landuse = 'retail'
		OR building = 'retail';

-- set points on polygons
UPDATE  generated.neighborhood_retail
SET     geom_pt = ST_Centroid(geom_poly);

-- index
CREATE INDEX sidx_neighborhood_retail_geomply ON neighborhood_retail USING GIST (geom_poly);
ANALYZE generated.neighborhood_retail (geom_poly);

-- set blockid10
UPDATE  generated.neighborhood_retail
SET     blockid10 = array((
            SELECT  cb.blockid10
            FROM    neighborhood_census_blocks cb
            WHERE   ST_Intersects(neighborhood_retail.geom_poly,cb.geom)
        ));

-- block index
CREATE INDEX IF NOT EXISTS aidx_neighborhood_retail_blockid10 ON neighborhood_retail USING GIN (blockid10);
ANALYZE generated.neighborhood_retail (blockid10);
