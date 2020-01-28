----------------------------------------
-- INPUTS
-- location: neighborhood
----------------------------------------
UPDATE  neighborhood_ways
SET     ft_lanes = NULL, tf_lanes = NULL, ft_cross_lanes = NULL, tf_cross_lanes = NULL;

UPDATE  neighborhood_ways
SET     ft_lanes =
            CASE    WHEN osm."turn:lanes:forward" IS NOT NULL
                        THEN    array_length(
                                    regexp_split_to_array(
                                        osm."turn:lanes:forward",
                                        '\|'
                                    ),
                                    1       -- only one dimension
                                )
                    WHEN osm."turn:lanes" IS NOT NULL AND osm."oneway" IN ('1', 'yes')
                        THEN    array_length(
                                    regexp_split_to_array(
                                        osm."turn:lanes",
                                        '\|'
                                    ),
                                    1       -- only one dimension
                                )
                    WHEN osm."lanes:forward" IS NOT NULL
                        THEN    substring(osm."lanes:forward" FROM '\d+')::INT
                    WHEN osm."lanes" IS NOT NULL AND osm."oneway" IN ('1', 'yes')
                        THEN    substring(osm."lanes" FROM '\d+')::INT
                    WHEN osm."lanes" IS NOT NULL AND (osm."oneway" IS NULL OR osm."oneway" = 'no')
                        THEN    ceil(substring(osm."lanes" FROM '\d+')::FLOAT / 2)
                    END,
        tf_lanes =
                    CASE    WHEN osm."turn:lanes:backward" IS NOT NULL
                                THEN    array_length(
                                            regexp_split_to_array(
                                                osm."turn:lanes:backward",
                                                '\|'
                                            ),
                                            1       -- only one dimension
                                        )
                            WHEN osm."turn:lanes" IS NOT NULL AND osm."oneway" = '-1'
                                THEN    array_length(
                                            regexp_split_to_array(
                                                osm."turn:lanes",
                                                '\|'
                                            ),
                                            1       -- only one dimension
                                        )
                            WHEN osm."lanes:backward" IS NOT NULL
                                THEN    substring(osm."lanes:backward" FROM '\d+')::INT
                            WHEN osm."lanes" IS NOT NULL AND osm."oneway" = '-1'
                                THEN    substring(osm."lanes" FROM '\d+')::INT
                            WHEN osm."lanes" IS NOT NULL AND (osm."oneway" IS NULL OR osm."oneway" = 'no')
                                THEN    ceil(substring(osm."lanes" FROM '\d+')::FLOAT / 2)
                            END,
        ft_cross_lanes =
            CASE    WHEN osm."turn:lanes:forward" IS NOT NULL
                        THEN    array_length(
                                    array_remove(
                                        regexp_split_to_array(
                                            osm."turn:lanes:forward",
                                            '\|'
                                        ),
                                        'right'     -- don't consider right-only lanes for crossing stress
                                    ),
                                    1               -- only one dimension
                                )
                    WHEN osm."turn:lanes" IS NOT NULL AND osm."oneway" IN ('1', 'yes')
                        THEN    array_length(
                                    array_remove(
                                        regexp_split_to_array(
                                            osm."turn:lanes",
                                            '\|'
                                        ),
                                        'right'     -- don't consider right-only lanes for crossing stress
                                    ),
                                    1               -- only one dimension
                                )
                    WHEN osm."lanes:forward" IS NOT NULL
                        THEN    substring(osm."lanes:forward" FROM '\d+')::INT
                    WHEN osm."lanes" IS NOT NULL AND osm."oneway" IN ('1', 'yes')
                        THEN    substring(osm."lanes" FROM '\d+')::INT
                    WHEN osm."lanes" IS NOT NULL AND (osm."oneway" IS NULL OR osm."oneway" = 'no')
                        THEN    ceil(substring(osm."lanes" FROM '\d+')::FLOAT / 2)
                    END,
        tf_cross_lanes =
            CASE    WHEN osm."turn:lanes:backward" IS NOT NULL
                        THEN    array_length(
                                    array_remove(
                                        regexp_split_to_array(
                                            osm."turn:lanes:backward",
                                            '\|'
                                        ),
                                        'right'     -- don't consider right-only lanes for crossing stress
                                    ),
                                    1               -- only one dimension
                                )
                    WHEN osm."turn:lanes" IS NOT NULL AND osm."oneway" = '-1'
                        THEN    array_length(
                                    array_remove(
                                        regexp_split_to_array(
                                            osm."turn:lanes",
                                            '\|'
                                        ),
                                        'right'     -- don't consider right-only lanes for crossing stress
                                    ),
                                    1               -- only one dimension
                                )
                    WHEN osm."lanes:backward" IS NOT NULL
                        THEN    substring(osm."lanes:backward" FROM '\d+')::INT
                    WHEN osm."lanes" IS NOT NULL AND osm."oneway" = '-1'
                        THEN    substring(osm."lanes" FROM '\d+')::INT
                    WHEN osm."lanes" IS NOT NULL AND (osm."oneway" IS NULL OR osm."oneway" = 'no')
                        THEN    ceil(substring(osm."lanes" FROM '\d+')::FLOAT / 2)
                    END,
        twltl_cross_lanes =
            CASE    WHEN osm."lanes:both_ways" IS NOT NULL THEN 1
                    WHEN osm."turn:lanes:both_ways" IS NOT NULL THEN 1
                    ELSE NULL
                    END
FROM    neighborhood_osm_full_line osm
WHERE   neighborhood_ways.osm_id = osm.osm_id;

-- -- forward
-- UPDATE  neighborhood_ways
-- SET     ft_lanes = substring(osm."lanes:forward" FROM '\d+')::INT
-- FROM    neighborhood_osm_full_line osm
-- WHERE   neighborhood_ways.osm_id = osm.osm_id
-- AND     ft_lanes IS NULL
-- AND     osm."lanes:forward" IS NOT NULL;
--
-- -- backward
-- UPDATE  neighborhood_ways
-- SET     tf_lanes = substring(osm."lanes:backward" FROM '\d+')::INT
-- FROM    neighborhood_osm_full_line osm
-- WHERE   neighborhood_ways.osm_id = osm.osm_id
-- AND     tf_lanes IS NULL
-- AND     osm."lanes:backward" IS NOT NULL;
--
-- -- all lanes (no direction given)
-- -- two way
-- UPDATE  neighborhood_ways
-- SET     ft_lanes = floor(substring(osm.lanes FROM '\d+')::FLOAT / 2),
--         tf_lanes = floor(substring(osm.lanes FROM '\d+')::FLOAT / 2)
-- FROM    neighborhood_osm_full_line osm
-- WHERE   neighborhood_ways.osm_id = osm.osm_id
-- AND     tf_lanes IS NULL
-- AND     ft_lanes IS NULL
-- AND     one_way_car NOT IN ('ft','tf')
-- AND     osm.lanes IS NOT NULL;
--
-- -- all lanes (no direction given)
-- -- one way
-- UPDATE  neighborhood_ways
-- SET     ft_lanes = substring(osm.lanes FROM '\d+')::INT
-- FROM    neighborhood_osm_full_line osm
-- WHERE   neighborhood_ways.osm_id = osm.osm_id
-- AND     one_way_car = 'ft'
-- AND     ft_lanes IS NULL
-- AND     osm.lanes IS NOT NULL;
-- UPDATE  neighborhood_ways
-- SET     tf_lanes = substring(osm.lanes FROM '\d+')::INT
-- FROM    neighborhood_osm_full_line osm
-- WHERE   neighborhood_ways.osm_id = osm.osm_id
-- AND     one_way_car = 'tf'
-- AND     tf_lanes IS NULL
-- AND     osm.lanes IS NOT NULL;
