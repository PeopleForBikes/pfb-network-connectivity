----------------------------------------
-- Stress ratings at intersection for
--      tertiary ways
-- Input variables:
--      :primary_speed -> assumed speed limit for primary roads
--      :secondary_speed -> assumed speed limit for secondary roads
--      :primary_lanes -> assumed number of lanes for primary roads (only 1/2 the road)
--      :secondary_lanes -> assumed number of lanes for secondary roads (only 1/2 the road)
----------------------------------------
UPDATE  neighborhood_ways SET ft_int_stress = 1, tf_int_stress = 1
WHERE   functional_class = 'tertiary';

-- ft
UPDATE  neighborhood_ways
SET     ft_int_stress = 3
FROM    neighborhood_ways_intersections i
WHERE   functional_class = 'tertiary'
AND     neighborhood_ways.intersection_to = i.int_id
AND     NOT i.signalized
AND     NOT i.stops
AND     EXISTS (
            SELECT  1
            FROM    neighborhood_ways w
            WHERE   i.int_id IN (w.intersection_to,w.intersection_from)
            AND     COALESCE(neighborhood_ways.name,'a') != COALESCE(w.name,'b')
            AND     CASE
                    WHEN w.functional_class IN ('motorway','trunk') THEN TRUE

                    -- two way primary
                    WHEN w.functional_class = 'primary' AND w.one_way IS NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) > 4 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 65 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 55
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) = 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END
                                END

                    -- one way primary
                    WHEN w.functional_class = 'primary' AND w.one_way IS NOT NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) > 2 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 65 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 55 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END
                                END

                    -- two way secondary
                    WHEN w.functional_class = 'secondary' AND w.one_way IS NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) > 4 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 65 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 55
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) = 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END
                                END

                    -- one way secondary
                    WHEN w.functional_class = 'secondary' AND w.one_way IS NOT NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) > 2 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 65 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 55
                                                            THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50
                                                            THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END
                                END
                    END
);


-- tf
UPDATE  neighborhood_ways
SET     tf_int_stress = 3
FROM    neighborhood_ways_intersections i
WHERE   functional_class = 'tertiary'
AND     neighborhood_ways.intersection_from = i.int_id
AND     NOT i.signalized
AND     NOT i.stops
AND     EXISTS (
            SELECT  1
            FROM    neighborhood_ways w
            WHERE   i.int_id IN (w.intersection_to,w.intersection_from)
            AND     COALESCE(neighborhood_ways.name,'a') != COALESCE(w.name,'b')
            AND     CASE
                    WHEN w.functional_class IN ('motorway','trunk') THEN TRUE

                    -- two way primary
                    WHEN w.functional_class = 'primary' AND w.one_way IS NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) > 4 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 65 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 55
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) = 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:primary_lanes) + COALESCE(w.tf_lanes,:primary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END
                                END

                    -- one way primary
                    WHEN w.functional_class = 'primary' AND w.one_way IS NOT NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) > 2 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 65 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 55 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:primary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:primary_speed) > 50 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END
                                END

                    -- two way secondary
                    WHEN w.functional_class = 'secondary' AND w.one_way IS NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) > 4 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 65 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 55
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) = 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50 THEN TRUE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) = 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,:secondary_lanes) + COALESCE(w.tf_lanes,:secondary_lanes) < 4
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50
                                                            THEN    CASE
                                                                    WHEN i.island THEN FALSE
                                                                    ELSE TRUE
                                                                    END
                                                        ELSE FALSE
                                                        END
                                            END
                                END

                    -- one way secondary
                    WHEN w.functional_class = 'secondary' AND w.one_way IS NOT NULL
                        THEN    CASE
                                WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) > 2 THEN TRUE

                                -- with rrfb
                                WHEN i.rrfb
                                    THEN    CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 65 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 55
                                                            THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END

                                -- without rrfb
                                ELSE        CASE
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) = 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50 THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            WHEN COALESCE(w.ft_lanes,w.tf_lanes,:secondary_lanes) < 2
                                                THEN    CASE
                                                        WHEN COALESCE(w.speed_limit,:secondary_speed) > 50
                                                            THEN TRUE
                                                        ELSE FALSE
                                                        END
                                            END
                                END
                    END
);
