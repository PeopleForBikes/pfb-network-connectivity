----------------------------------------
-- INPUTS
-- location: neighborhood
----------------------------------------
UPDATE  neighborhood_ways SET functional_class = NULL;

UPDATE  neighborhood_ways
SET     functional_class = osm.highway
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id
AND     osm.highway IN (
            'motorway',
            'tertiary',
            'trunk',
            'tertiary_link',
            'motorway_link',
            'secondary_link',
            'primary_link',
            'trunk_link',
            'unclassified',
            'residential',
            'secondary',
            'primary',
            'living_street'
);

UPDATE  neighborhood_ways
SET     functional_class = 'track'
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id
AND     osm.highway = 'track'
AND     osm.tracktype = 'grade1';

UPDATE  neighborhood_ways
SET     functional_class = 'path'
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id
AND     osm.highway IN ('cycleway','path');

UPDATE  neighborhood_ways
SET     functional_class = 'path',
        xwalk = 1
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id
AND     osm.highway = 'footway'
AND     osm.footway = 'crossing';

UPDATE  neighborhood_ways
SET     functional_class = 'path'
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id
AND     osm.highway = 'footway'
AND     osm.bicycle IN ('yes','permissive', 'designated')
AND     (osm.access IS NULL OR osm.access NOT IN ('no','private'))
AND     COALESCE(width_ft,0) >= 8;

UPDATE  neighborhood_ways
SET     functional_class = 'path'
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id
AND     osm.highway='service'
AND     osm.bicycle IN ('yes','permissive', 'designated');

UPDATE  neighborhood_ways
SET     functional_class = 'living_street'
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id
AND     osm.highway = 'pedestrian'
AND     osm.bicycle IN ('yes','permissive', 'designated')
AND     (osm.access IS NULL OR osm.access NOT IN ('no','private'));

-- remove stuff that we don't want to route over
DELETE FROM neighborhood_ways WHERE functional_class IS NULL;

-- remove orphans
DELETE FROM neighborhood_ways
WHERE   NOT EXISTS (
            SELECT  1
            FROM    neighborhood_ways w
            WHERE   neighborhood_ways.intersection_to IN (w.intersection_to,w.intersection_from)
            AND     w.road_id != neighborhood_ways.road_id
)
AND     NOT EXISTS (
            SELECT  1
            FROM    neighborhood_ways w
            WHERE   neighborhood_ways.intersection_from IN (w.intersection_to,w.intersection_from)
            AND     w.road_id != neighborhood_ways.road_id
);

-- remove obsolete intersections
DELETE FROM neighborhood_ways_intersections
WHERE NOT EXISTS (
    SELECT  1
    FROM    neighborhood_ways w
    WHERE   int_id IN (w.intersection_to,w.intersection_from)
);
