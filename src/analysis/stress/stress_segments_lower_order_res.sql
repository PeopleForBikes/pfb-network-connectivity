----------------------------------------
-- Stress ratings for:
--      residential
-- Input variables:
--      :class -> functional class to operate on
--      :default_lanes -> assumed number of lanes
--      :default_parking -> assumed parking 1/0
--      :default_roadway_width -> assumed width of roadway
--      :state_default -> state default residential speed
-- 		:city_default -> city default residential speed
----------------------------------------
UPDATE  received.neighborhood_ways SET ft_seg_stress=NULL, tf_seg_stress=NULL
WHERE   functional_class = :'class';

UPDATE  received.neighborhood_ways
SET     ft_seg_stress =
            CASE
            WHEN COALESCE(speed_limit, :city_default, :state_default) = 40
                THEN    CASE
                        WHEN COALESCE(ft_park,:default_parking) + COALESCE(tf_park,:default_parking) = 2    -- parking on both sides
                            THEN    CASE
                                    WHEN COALESCE(width_ft,:default_roadway_width) >= 27
                                        THEN 1
                                    ELSE 2
                                    END
                        ELSE    CASE                                                                        -- parking on one side
                                WHEN COALESCE(width_ft,:default_roadway_width) >= 19
                                    THEN 1
                                ELSE 2
                                END
                        END
            WHEN COALESCE(speed_limit, :city_default, :state_default) <= 30 THEN 1
            ELSE 3
            END,
        tf_seg_stress =
            CASE
            WHEN COALESCE(speed_limit, :city_default, :state_default) = 40
                THEN    CASE
                        WHEN COALESCE(ft_park,:default_parking) + COALESCE(tf_park,:default_parking) = 2    -- parking on both sides
                            THEN    CASE
                                    WHEN COALESCE(width_ft,:default_roadway_width) >= 27
                                        THEN 1
                                    ELSE 2
                                    END
                        ELSE    CASE                                                                        -- parking on one side
                                WHEN COALESCE(width_ft,:default_roadway_width) >= 19
                                    THEN 1
                                ELSE 2
                                END
                        END
            WHEN COALESCE(speed_limit, :city_default, :state_default) <= 30 THEN 1
            ELSE 3
            END
WHERE   functional_class = :'class';
