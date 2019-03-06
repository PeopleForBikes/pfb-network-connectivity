----------------------------------------
-- Adjusts functional class on residential
-- and unclassified with bike facilities
-- or multiple travel lanes to be
-- tertiary
----------------------------------------
UPDATE  received.neighborhood_ways
SET     functional_class = 'tertiary'
WHERE   functional_class IN ('residential','unclassified')
AND     (
            ft_bike_infra IN ('track','buffered_lane','lane')
        OR  tf_bike_infra IN ('track','buffered_lane','lane')
        OR  ft_lanes > 1
        OR  tf_lanes > 1
        OR  speed_limit >= 50
        );
