----------------------------------------
-- INPUTS
-- location: neighborhood
-- Takes the inputs from neighborhood_neighborhood_score_inputs
--   and converts to scores for each of the
--   subcategories. Then, combines the
--   subcategory scores into an overall category
--   score. Finally, combines category scores into
--   a single master score for the entire
--   neighborhood.
--
-- variables:
--   :total=100
--   :people=15
--   :opportunity=25
--   :core_services=25
--   :recreation=10
--   :retail=10
--   :transit=15
----------------------------------------
DROP TABLE IF EXISTS generated.neighborhood_overall_scores;

CREATE TABLE generated.neighborhood_overall_scores (
    id SERIAL PRIMARY KEY,
    score_id TEXT,
    score_original NUMERIC(16,4),
    score_normalized NUMERIC(16,4),
    human_explanation TEXT
);

-- population
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'people',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_pop;

-- k12 education
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'opportunity_k12_education',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_k12;

-- tech school
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'opportunity_technical_vocational_college',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_tech;

-- higher ed
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'opportunity_higher_education',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_univ;

-- opportunity
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'opportunity',
        CASE
        WHEN EXISTS (
            SELECT  1
            FROM    neighborhood_census_blocks
            WHERE   schools_high_stress > 0
            OR      colleges_high_stress > 0
            OR      universities_high_stress > 0
        )
            THEN    (
                        0.55 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'opportunity_k12_education')
                        + 0.15 * (select score_original from neighborhood_overall_scores where score_id = 'opportunity_technical_vocational_college')
                        + 0.3 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'opportunity_higher_education')
                    ) /
                    (
                        CASE
                        WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE schools_high_stress > 0)
                            THEN 0.55
                        ELSE 0
                        END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE colleges_high_stress > 0)
                                THEN 0.15
                            ELSE 0
                            END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE universities_high_stress > 0)
                                THEN 0.30
                            ELSE 0
                            END
                    )
        ELSE NULL
        END,
        NULL;

-- doctors
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'core_services_doctors',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_doctor;

-- dentists
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'core_services_dentists',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_dentist;

-- hospitals
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'core_services_hospitals',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_hospital;

-- pharmacies
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'core_services_pharmacies',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_pharmacy;

-- grocery
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'core_services_grocery',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_grocery;

-- social services
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'core_services_social_services',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_social_svcs;

-- core services
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'core_services',
        CASE
        WHEN EXISTS (
            SELECT  1
            FROM    neighborhood_census_blocks
            WHERE   doctors_high_stress > 0
            OR      dentists_high_stress > 0
            OR      hospitals_high_stress > 0
            OR      pharmacies_high_stress > 0
            OR      supermarkets_high_stress > 0
            OR      social_services_high_stress > 0
        )
            THEN    (
                        0.2 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'core_services_doctors')
                        + 0.1 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'core_services_dentists')
                        + 0.2 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'core_services_hospitals')
                        + 0.1 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'core_services_pharmacies')
                        + 0.25 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'core_services_grocery')
                        + 0.15 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'core_services_social_services')
                    ) /
                    (
                        CASE
                        WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE doctors_high_stress > 0)
                            THEN 0.2
                        ELSE 0
                        END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE dentists_high_stress > 0)
                                THEN 0.1
                            ELSE 0
                            END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE hospitals_high_stress > 0)
                                THEN 0.2
                            ELSE 0
                            END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE pharmacies_high_stress > 0)
                                THEN 0.1
                            ELSE 0
                            END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE supermarkets_high_stress > 0)
                                THEN 0.25
                            ELSE 0
                            END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE social_services_high_stress > 0)
                                THEN 0.15
                            ELSE 0
                            END
                    )
        ELSE NULL
        END,
        NULL;

-- retail
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'retail',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_retail;

-- parks
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'recreation_parks',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_parks;

-- trails
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'recreation_trails',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_trails;

-- community_centers
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'recreation_community_centers',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_comm_ctrs;

-- recreation
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'recreation',
        CASE
        WHEN EXISTS (
            SELECT  1
            FROM    neighborhood_census_blocks
            WHERE   parks_high_stress > 0
            OR      trails_high_stress > 0
            OR      community_centers_high_stress > 0
        )
            THEN    (
                        0.4 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'recreation_parks')
                        + 0.35 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'recreation_trails')
                        + 0.25 * (SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'recreation_community_centers')
                    ) /
                    (
                        CASE
                        WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE parks_high_stress > 0)
                            THEN 0.4
                        ELSE 0
                        END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE trails_high_stress > 0)
                                THEN 0.35
                            ELSE 0
                            END
                        +   CASE
                            WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE community_centers_high_stress > 0)
                                THEN 0.25
                            ELSE 0
                            END
                    )
        ELSE NULL
        END,
        NULL;

-- transit
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'transit',
        COALESCE(neighborhood_score_inputs.score,0),
        neighborhood_score_inputs.human_explanation
FROM    neighborhood_score_inputs
WHERE   use_transit;

-- calculate overall neighborhood score
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'overall_score',
        (
            :people * COALESCE((SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'people'),0)
            + :opportunity * COALESCE((SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'opportunity'),0)
            + :core_services * COALESCE((SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'core_services'),0)
            + :retail * COALESCE((SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'retail'),0)
            + :recreation * COALESCE((SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'recreation'),0)
            + :transit * COALESCE((SELECT score_original FROM neighborhood_overall_scores WHERE score_id = 'transit'),0)
        ) /
        (
            :people + :opportunity
            +   CASE
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE doctors_high_stress > 0)
                    THEN :core_services
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE dentists_high_stress > 0)
                    THEN :core_services
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE hospitals_high_stress > 0)
                    THEN :core_services
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE pharmacies_high_stress > 0)
                    THEN :core_services
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE supermarkets_high_stress > 0)
                    THEN :core_services
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE social_services_high_stress > 0)
                    THEN :core_services
                ELSE 0
                END
            +   CASE
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE retail_high_stress > 0)
                    THEN :retail
                ELSE 0
                END
            +   CASE
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE parks_high_stress > 0)
                    THEN :recreation
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE trails_high_stress > 0)
                    THEN :recreation
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE community_centers_high_stress > 0)
                    THEN :recreation
                ELSE 0
                END
            +   CASE
                WHEN EXISTS (SELECT 1 FROM neighborhood_census_blocks WHERE transit_high_stress > 0)
                    THEN :transit
                ELSE 0
                END
        ),
        NULL;

-- normalize
UPDATE  generated.neighborhood_overall_scores
SET     score_normalized = score_original * :total;

-- population
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT  'population_total',
        (
            SELECT SUM(pop10) FROM neighborhood_census_blocks
            WHERE   EXISTS (
                        SELECT  1
                        FROM    neighborhood_boundary AS b
                        WHERE   ST_Intersects(b.geom,neighborhood_census_blocks.geom)
                    )
        ),
        'Total population of boundary';


-- high and low stress total mileage
INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT 'total_miles_low_stress',
    (
        SELECT
            ( 1 / 1609.34 ) * (
                SUM(ST_Length(ST_Intersection(w.geom, b.geom)) *
                    CASE ft_seg_stress WHEN 1 THEN 1 ELSE 0 END) +
                SUM(ST_Length(ST_Intersection(w.geom, b.geom)) *
                    CASE tf_seg_stress WHEN 1 THEN 1 ELSE 0 END)
            ) as dist
        FROM neighborhood_ways as w, neighborhood_boundary as b
        WHERE ST_Intersects(w.geom, b.geom)
    ),
    'Total low-stress miles';

INSERT INTO generated.neighborhood_overall_scores (
    score_id, score_original, human_explanation
)
SELECT 'total_miles_high_stress',
    (
        SELECT
            ( 1 / 1609.34 ) * (
                SUM(ST_Length(ST_Intersection(w.geom, b.geom)) *
                    CASE ft_seg_stress WHEN 3 THEN 1 ELSE 0 END) +
                SUM(ST_Length(ST_Intersection(w.geom, b.geom)) *
                    CASE tf_seg_stress WHEN 3 THEN 1 ELSE 0 END)
            ) as dist
        FROM neighborhood_ways as w, neighborhood_boundary as b
        WHERE ST_Intersects(w.geom, b.geom)
    ),
    'Total high-stress miles';

UPDATE generated.neighborhood_overall_scores
SET    score_normalized = ROUND(score_original, 1)
WHERE  score_id in ('total_miles_low_stress', 'total_miles_high_stress');
