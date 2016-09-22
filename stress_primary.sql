----------------------------------------
-- INPUTS
-- location: cambridge
----------------------------------------
UPDATE  cambridge_ways SET ft_seg_stress = NULL, tf_seg_stress = NULL
WHERE   functional_class IN ('primary','primary_link');

-- ft direction
UPDATE  cambridge_ways
SET     ft_seg_stress =
            CASE
            WHEN ft_bike_infra = 'track' THEN 1
            WHEN ft_bike_infra = 'buffered_lane'
                    THEN    CASE
                            WHEN speed_limit = 35 THEN  CASE
                                                        WHEN ft_lanes = 1 THEN 2
                                                        ELSE 3
                                                        END
                            WHEN speed_limit <= 30 THEN CASE
                                                        WHEN ft_lanes = 1 THEN 1
                                                        ELSE 3
                                                        END
                            ELSE 3
                            END
            WHEN ft_bike_infra = 'lane'
                    THEN    CASE
                            WHEN speed_limit <= 25
                                    THEN    CASE
                                            WHEN ft_lanes = 1 THEN  CASE
                                                                    WHEN ft_park = 0 THEN 1
                                                                    ELSE 2
                                                                    END
                                            WHEN ft_lanes > 2 THEN  3
                                            ELSE    CASE
                                                    WHEN ft_park = 0 THEN 2
                                                    ELSE 3
                                                    END
                                            END
                            WHEN speed_limit = 30 THEN  CASE
                                                        WHEN ft_lanes = 1 THEN
                                                                CASE
                                                                WHEN ft_park = 0 THEN 1
                                                                ELSE 2
                                                                END
                                                        ELSE 3
                                                        END
                            ELSE 3
                            END
            ELSE 3
            END
WHERE   functional_class IN ('primary','primary_link');

-- tf direction
UPDATE  cambridge_ways
SET     tf_seg_stress =
            CASE
            WHEN tf_bike_infra = 'track' THEN 1
            WHEN tf_bike_infra = 'buffered_lane'
                    THEN    CASE
                            WHEN speed_limit = 35 THEN  CASE
                                                        WHEN tf_lanes = 1 THEN 2
                                                        ELSE 3
                                                        END
                            WHEN speed_limit <= 30 THEN CASE
                                                        WHEN tf_lanes = 1 THEN 1
                                                        ELSE 3
                                                        END
                            ELSE 3
                            END
            WHEN tf_bike_infra = 'lane'
                    THEN    CASE
                            WHEN speed_limit <= 25
                                    THEN    CASE
                                            WHEN tf_lanes = 1 THEN  CASE
                                                                    WHEN tf_park = 0 THEN 1
                                                                    ELSE 2
                                                                    END
                                            WHEN tf_lanes > 2 THEN  3
                                            ELSE    CASE
                                                    WHEN tf_park = 0 THEN 2
                                                    ELSE 3
                                                    END
                                            END
                            WHEN speed_limit = 30 THEN  CASE
                                                        WHEN tf_lanes = 1 THEN
                                                                CASE
                                                                WHEN tf_park = 0 THEN 1
                                                                ELSE 2
                                                                END
                                                        ELSE 3
                                                        END
                            ELSE 3
                            END
            ELSE 3
            END
WHERE   functional_class IN ('primary','primary_link');
