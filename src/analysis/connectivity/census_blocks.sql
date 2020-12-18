----------------------------------------
-- INPUTS
-- location: neighborhood
-- code to be run on table that has
-- been imported directly from US Census
-- blkpophu file
-- :nb_output_srid psql, :block_road_buffer, and :block_road_min_length vars
-- must be set before running this script,
--      e.g. psql -v nb_output_srid=2163 -v block_road_buffer=15
--                -v block_road_min_length=30 -f census_blocks.sql
----------------------------------------

ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS job_count;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS road_ids;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS pop_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS pop_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS pop_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS emp_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS emp_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS emp_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS schools_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS schools_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS schools_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS universities_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS universities_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS universities_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS colleges_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS colleges_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS colleges_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS doctors_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS doctors_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS doctors_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS dentists_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS dentists_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS dentists_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS hospitals_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS hospitals_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS hospitals_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS pharmacies_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS pharmacies_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS pharmacies_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS retail_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS retail_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS retail_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS supermarkets_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS supermarkets_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS supermarkets_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS social_services_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS social_services_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS social_services_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS parks_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS parks_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS parks_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS trails_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS trails_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS trails_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS community_centers_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS community_centers_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS community_centers_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS transit_low_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS transit_high_stress;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS transit_score;
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS overall_score;

ALTER TABLE neighborhood_census_blocks ADD COLUMN job_count INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN road_ids INTEGER[];
ALTER TABLE neighborhood_census_blocks ADD COLUMN pop_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN pop_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN pop_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN emp_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN emp_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN emp_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN schools_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN schools_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN schools_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN universities_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN universities_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN universities_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN colleges_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN colleges_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN colleges_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN doctors_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN doctors_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN doctors_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN dentists_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN dentists_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN dentists_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN hospitals_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN hospitals_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN hospitals_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN pharmacies_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN pharmacies_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN pharmacies_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN retail_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN retail_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN retail_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN supermarkets_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN supermarkets_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN supermarkets_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN social_services_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN social_services_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN social_services_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN parks_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN parks_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN parks_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN trails_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN trails_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN trails_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN community_centers_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN community_centers_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN community_centers_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN transit_low_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN transit_high_stress INT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN transit_score FLOAT;
ALTER TABLE neighborhood_census_blocks ADD COLUMN overall_score FLOAT;

-- indexes
CREATE INDEX IF NOT EXISTS idx_neighborhood_blocks10 ON neighborhood_census_blocks (blockid10);
CREATE INDEX IF NOT EXISTS idx_neighborhood_geom ON neighborhood_census_blocks USING GIST (geom);
ANALYZE neighborhood_census_blocks;

------------------------------
-- add road_ids
------------------------------
ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS tmp_geom_buffer;
ALTER TABLE neighborhood_census_blocks ADD COLUMN tmp_geom_buffer geometry(multipolygon, :nb_output_srid);

UPDATE  neighborhood_census_blocks
SET     tmp_geom_buffer = ST_Multi(ST_Buffer(geom,:block_road_buffer));
CREATE INDEX tsidx_neighborhood_cblockbuffgeoms ON neighborhood_census_blocks USING GIST (tmp_geom_buffer);
ANALYZE neighborhood_census_blocks (tmp_geom_buffer);

UPDATE  neighborhood_census_blocks
SET     road_ids = array((
            SELECT  ways.road_id
            FROM    neighborhood_ways ways
            WHERE   ST_Intersects(neighborhood_census_blocks.tmp_geom_buffer,ways.geom)
            AND     (
                        ST_Contains(neighborhood_census_blocks.tmp_geom_buffer,ways.geom)
                    OR  ST_Length(
                            ST_Intersection(neighborhood_census_blocks.tmp_geom_buffer,ways.geom)
                        ) > :block_road_min_length
                    )
        ));

ALTER TABLE neighborhood_census_blocks DROP COLUMN IF EXISTS tmp_geom_buffer;

-- index
CREATE INDEX aidx_neighborhood_census_blocks_road_ids ON neighborhood_census_blocks USING GIN (road_ids);
ANALYZE neighborhood_census_blocks (road_ids);
