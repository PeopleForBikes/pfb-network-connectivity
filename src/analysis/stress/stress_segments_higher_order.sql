----------------------------------------
-- Stress ratings for:
--      motorway
--      trunk
--      primary
--      secondary
--      tertiary
--      (and all _links)
-- Input variables:
--      :class -> functional class to operate on
--      :default_speed -> assumed speed limit
--      :default_lanes -> assumed number of lanes
--      :default_parking -> assumed parking 1/0
--      :default_parking_width -> assumed parking lane width
--      :default_facility_width -> assumed width of bike facility
----------------------------------------
UPDATE  neighborhood_ways SET ft_seg_stress = NULL, tf_seg_stress = NULL
WHERE   functional_class IN (:'class',:'class'||'_link');

-- ft direction
UPDATE  neighborhood_ways
SET     ft_seg_stress =
            CASE
            WHEN ft_bike_infra = 'track' THEN 1
            WHEN ft_bike_infra = 'buffered_lane'
                THEN    CASE
                        WHEN COALESCE(speed_limit,:default_speed) > 35 THEN 3
                        WHEN COALESCE(speed_limit,:default_speed) = 35
                            THEN    CASE
                                    WHEN COALESCE(ft_lanes,:default_lanes) > 1 THEN 3
                                    ELSE    CASE
                                            WHEN COALESCE(ft_park,:default_parking) = 1 THEN 2
                                            ELSE 1
                                            END
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) = 30
                            THEN    CASE
                                    WHEN COALESCE(ft_lanes,:default_lanes) > 1
                                        THEN    CASE
                                                WHEN COALESCE(ft_park,:default_parking) = 1 THEN 2
                                                ELSE 1
                                                END
                                    ELSE 1
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) < 30 THEN 1
                        ELSE 3
                        END
            WHEN ft_bike_infra = 'lane' AND COALESCE(ft_park,:default_parking) = 0  -- bike lane with no parking
                THEN    CASE
                        WHEN COALESCE(speed_limit,:default_speed) > 30 THEN 3
                        WHEN COALESCE(speed_limit,:default_speed) = 30
                            THEN    CASE
                                    WHEN COALESCE(ft_lanes,:default_lanes) > 1 THEN 3
                                    ELSE 1
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) = 25
                            THEN    CASE
                                    WHEN COALESCE(ft_lanes,:default_lanes) > 1 THEN 3
                                    ELSE 1
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) <= 20
                            THEN    CASE
                                    WHEN COALESCE(ft_lanes,:default_lanes) > 2 THEN 3
                                    ELSE 1
                                    END
                        ELSE 3
                        END
            WHEN ft_bike_infra = 'lane' AND COALESCE(ft_park,:default_parking) = 1
                THEN    CASE
                        WHEN COALESCE(ft_bike_infra_width,:default_facility_width) + :default_parking_width >= 15   -- treat as buffered lane
                            THEN    CASE
                                    WHEN COALESCE(speed_limit,:default_speed) > 35 THEN 3
                                    WHEN COALESCE(speed_limit,:default_speed) = 35 THEN 3
                                    WHEN COALESCE(speed_limit,:default_speed) = 30
                                        THEN    CASE
                                                WHEN COALESCE(ft_lanes,:default_lanes) > 1 THEN 2
                                                ELSE 1
                                                END
                                    WHEN COALESCE(speed_limit,:default_speed) < 30 THEN 1
                                    ELSE 3
                                    END
                        WHEN COALESCE(ft_bike_infra_width,:default_facility_width) + :default_parking_width >= 12.9   -- treat as bike lane with no parking
                            THEN    CASE
                                    WHEN COALESCE(speed_limit,:default_speed) > 30 THEN 3
                                    WHEN COALESCE(speed_limit,:default_speed) = 30
                                        THEN    CASE
                                                WHEN COALESCE(ft_lanes,:default_lanes) > 1 THEN 3
                                                ELSE 1
                                                END
                                    WHEN COALESCE(speed_limit,:default_speed) = 25
                                        THEN    CASE
                                                WHEN COALESCE(ft_lanes,:default_lanes) > 1 THEN 3
                                                ELSE 1
                                                END
                                    WHEN COALESCE(speed_limit,:default_speed) <= 20
                                        THEN    CASE
                                                WHEN COALESCE(ft_lanes,:default_lanes) > 2 THEN 3
                                                ELSE 1
                                                END
                                    ELSE 3
                                    END
                        ELSE 3
                        END
            ELSE                -- shared lane
                        CASE
                        WHEN COALESCE(speed_limit,:default_speed) <= 20
                            THEN    CASE
                                    WHEN COALESCE(ft_lanes,:default_lanes) = 1 THEN 1
                                    ELSE 3
                                    END
                        ELSE 3
                        END
            END,
        tf_seg_stress =
            CASE
            WHEN tf_bike_infra = 'track' THEN 1
            WHEN tf_bike_infra = 'buffered_lane'
                THEN    CASE
                        WHEN COALESCE(speed_limit,:default_speed) > 35 THEN 3
                        WHEN COALESCE(speed_limit,:default_speed) = 35
                            THEN    CASE
                                    WHEN COALESCE(tf_lanes,:default_lanes) > 1 THEN 3
                                    ELSE    CASE
                                            WHEN COALESCE(tf_park,:default_parking) = 1 THEN 2
                                            ELSE 1
                                            END
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) = 30
                            THEN    CASE
                                    WHEN COALESCE(tf_lanes,:default_lanes) > 1
                                        THEN    CASE
                                                WHEN COALESCE(tf_park,:default_parking) = 1 THEN 2
                                                ELSE 1
                                                END
                                    ELSE 1
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) < 30 THEN 1
                        ELSE 3
                        END
            WHEN tf_bike_infra = 'lane' AND COALESCE(tf_park,:default_parking) = 0  -- bike lane with no parking
                THEN    CASE
                        WHEN COALESCE(speed_limit,:default_speed) > 30 THEN 3
                        WHEN COALESCE(speed_limit,:default_speed) = 30
                            THEN    CASE
                                    WHEN COALESCE(tf_lanes,:default_lanes) > 1 THEN 3
                                    ELSE 1
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) = 25
                            THEN    CASE
                                    WHEN COALESCE(tf_lanes,:default_lanes) > 1 THEN 3
                                    ELSE 1
                                    END
                        WHEN COALESCE(speed_limit,:default_speed) <= 20
                            THEN    CASE
                                    WHEN COALESCE(tf_lanes,:default_lanes) > 2 THEN 3
                                    ELSE 1
                                    END
                        ELSE 3
                        END
            WHEN tf_bike_infra = 'lane' AND COALESCE(tf_park,:default_parking) = 1
                THEN    CASE
                        WHEN COALESCE(tf_bike_infra_width,:default_facility_width) + :default_parking_width >= 15   -- treat as buffered lane
                            THEN    CASE
                                    WHEN COALESCE(speed_limit,:default_speed) > 35 THEN 3
                                    WHEN COALESCE(speed_limit,:default_speed) = 35 THEN 3
                                    WHEN COALESCE(speed_limit,:default_speed) = 30
                                        THEN    CASE
                                                WHEN COALESCE(tf_lanes,:default_lanes) > 1 THEN 2
                                                ELSE 1
                                                END
                                    WHEN COALESCE(speed_limit,:default_speed) < 30 THEN 1
                                    ELSE 3
                                    END
                        WHEN COALESCE(tf_bike_infra_width,:default_facility_width) + :default_parking_width >= 12.9   -- treat as bike lane with no parking
                            THEN    CASE
                                    WHEN COALESCE(speed_limit,:default_speed) > 30 THEN 3
                                    WHEN COALESCE(speed_limit,:default_speed) = 30
                                        THEN    CASE
                                                WHEN COALESCE(tf_lanes,:default_lanes) > 1 THEN 3
                                                ELSE 1
                                                END
                                    WHEN COALESCE(speed_limit,:default_speed) = 25
                                        THEN    CASE
                                                WHEN COALESCE(tf_lanes,:default_lanes) > 1 THEN 3
                                                ELSE 1
                                                END
                                    WHEN COALESCE(speed_limit,:default_speed) <= 20
                                        THEN    CASE
                                                WHEN COALESCE(tf_lanes,:default_lanes) > 2 THEN 3
                                                ELSE 1
                                                END
                                    ELSE 3
                                    END
                        ELSE 3
                        END
            ELSE                -- shared lane
                        CASE
                        WHEN COALESCE(speed_limit,:default_speed) <= 20
                            THEN    CASE
                                    WHEN COALESCE(tf_lanes,:default_lanes) = 1 THEN 1
                                    ELSE 3
                                    END
                        ELSE 3
                        END
            END
WHERE   functional_class IN (:'class',:'class'||'_link');
