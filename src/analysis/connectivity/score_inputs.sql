----------------------------------------
-- INPUTS
-- location: neighborhood
----------------------------------------
DROP TABLE IF EXISTS generated.neighborhood_score_inputs;

CREATE TABLE generated.neighborhood_score_inputs (
    id SERIAL PRIMARY KEY,
    category TEXT,
    score_name TEXT,
    score NUMERIC(16,4),
    notes TEXT,
    human_explanation TEXT,
    use_pop BOOLEAN,
    use_k12 BOOLEAN,
    use_tech BOOLEAN,
    use_univ BOOLEAN,
    use_doctor BOOLEAN,
    use_dentist BOOLEAN,
    use_hospital BOOLEAN,
    use_pharmacy BOOLEAN,
    use_retail BOOLEAN,
    use_grocery BOOLEAN,
    use_social_svcs BOOLEAN,
    use_parks BOOLEAN,
    use_trails BOOLEAN,
    use_comm_ctrs BOOLEAN,
    use_transit BOOLEAN
);

-------------------------------------
-- temporary table of total population
-- for weighting purposes
-------------------------------------
DROP TABLE IF EXISTS tmp_pop;
CREATE TEMP TABLE tmp_pop (
    overall INTEGER,
    k12 INTEGER,
    tech INTEGER,
    univ INTEGER,
    doctor INTEGER,
    dentist INTEGER,
    hospital INTEGER,
    pharmacy INTEGER,
    retail INTEGER,
    grocery INTEGER,
    social_svcs INTEGER,
    parks INTEGER,
    trails INTEGER,
    comm_ctrs INTEGER,
    transit INTEGER
);

INSERT INTO tmp_pop (
    overall, k12, tech, univ, doctor, dentist, hospital, pharmacy,
    retail, grocery, social_svcs, parks, trails, comm_ctrs, transit
)
SELECT  SUM(pop10),
        SUM(CASE WHEN COALESCE(schools_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(colleges_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(universities_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(doctors_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(dentists_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(hospitals_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(pharmacies_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(retail_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(supermarkets_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(social_services_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(parks_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(trails_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(community_centers_high_stress,0) = 0 THEN 0 ELSE pop10 END),
        SUM(CASE WHEN COALESCE(transit_high_stress,0) = 0 THEN 0 ELSE pop10 END)
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-------------------------------------
-- population
-------------------------------------
-- median pop access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'People',
        'Median score of access to population',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population accessible by low stress
            to population accessible overall, expressed as
            the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of all census blocks in the neighborhood have
            a ratio of low stress to high stress access above this number,
            half have a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile pop access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'People',
        '70th percentile score of access to population',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population accessible by low stress
            to population accessible overall, expressed as
            the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of all census blocks in the neighborhood have
            a ratio of low stress to high stress access above this number,
            70% have a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile pop access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'People',
        '30th percentile score of access to population',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population accessible by low stress
            to population accessible overall, expressed as
            the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of all census blocks in the neighborhood have
            a ratio of low stress to high stress access above this number,
            30% have a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- avg pop access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'People',
        'Average score of access to population',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population accessible by low stress
            to population accessible overall, expressed as
            the average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            this ratio of low stress to high stress access.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_pop
)
SELECT  'People',
        'Average score of access to population',
        SUM(CASE WHEN tmp_pop.overall = 0 THEN 0 ELSE pop10 * pop_score / tmp_pop.overall END),
        regexp_replace('Average population score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this population score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-------------------------------------
-- schools
-------------------------------------
-- average school access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Average score of low stress access to schools',
        CASE    WHEN SUM(schools_high_stress) = 0 THEN 0
                ELSE SUM(schools_low_stress) / SUM(schools_high_stress)
                END,
        regexp_replace('Number of schools accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many schools.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median schools access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Median score of school access',
        quantile(CASE WHEN schools_high_stress=0 THEN 0 ELSE schools_low_stress::FLOAT/schools_high_stress END,0.5),
        regexp_replace('Score of schools accessible by low stress
            compared to schools accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of schools within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile schools access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '70th percentile score of school access',
        quantile(CASE WHEN schools_high_stress=0 THEN 0 ELSE schools_low_stress::FLOAT/schools_high_stress END,0.7),
        regexp_replace('Score of schools accessible by low stress
            compared to schools accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of schools within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile schools access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '30th percentile score of school access',
        quantile(CASE WHEN schools_high_stress=0 THEN 0 ELSE schools_low_stress::FLOAT/schools_high_stress END,0.3),
        regexp_replace('Score of schools accessible by low stress
            compared to schools accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of schools within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_k12
)
SELECT  'Opportunity',
        'Average score of access to K12 schools',
        SUM(CASE WHEN tmp_pop.k12 = 0 THEN 0 ELSE pop10 * schools_score / tmp_pop.k12 END),
        regexp_replace('Average K12 schools score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this K12 schools score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- school pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Average school bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of schools in the neighborhood expressed as an average of
            all schools in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, schools in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_schools
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_schools.geom_pt,b.geom)
        );

-- school pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Median school population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to schools
            in the neighborhood to total population within the bike shed
            of each school expressed as a median of all
            schools in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of schools in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.','\n\s+',' ','g')
FROM    neighborhood_schools
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_schools.geom_pt,b.geom)
        );

-- school pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '70th percentile school population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to schools
            in the neighborhood to total population within the bike shed
            of each school expressed as the 70th percentile of all
            schools in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of schools in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.','\n\s+',' ','g')
FROM    neighborhood_schools
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_schools.geom_pt,b.geom)
        );

-- school pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '30th percentile school population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to schools
            in the neighborhood to total population within the bike shed
            of each school expressed as the 30th percentile of all
            schools in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of schools in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.','\n\s+',' ','g')
FROM    neighborhood_schools
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_schools.geom_pt,b.geom)
        );


-------------------------------------
-- technical/vocational colleges
-------------------------------------
-- average technical/vocational college access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Average score of low stress access to tech/vocational colleges',
        CASE    WHEN SUM(colleges_high_stress) = 0 THEN 0
                ELSE SUM(colleges_low_stress) / SUM(colleges_high_stress)
                END,
        regexp_replace('Number of tech/vocational colleges accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many tech/vocational colleges.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median colleges access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Median score of tech/vocational college access',
        quantile(CASE WHEN colleges_high_stress=0 THEN 0 ELSE colleges_low_stress::FLOAT/colleges_high_stress END,0.5),
        regexp_replace('Score of tech/vocational colleges accessible by low stress
            compared to tech/vocational colleges accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of tech/vocational colleges within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile colleges access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '70th percentile score of tech/vocational college access',
        quantile(CASE WHEN colleges_high_stress=0 THEN 0 ELSE colleges_low_stress::FLOAT/colleges_high_stress END,0.7),
        regexp_replace('Score of tech/vocational colleges accessible by low stress
            compared to tech/vocational colleges accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of tech/vocational colleges within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile colleges access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '30th percentile score of tech/vocational college access',
        quantile(CASE WHEN colleges_high_stress=0 THEN 0 ELSE colleges_low_stress::FLOAT/colleges_high_stress END,0.3),
        regexp_replace('Score of tech/vocational colleges accessible by low stress
            compared to tech/vocational colleges accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of tech/vocational colleges within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_tech
)
SELECT  'Opportunity',
        'Average score of access to tech/vocational colleges',
        SUM(CASE WHEN tmp_pop.tech = 0 THEN 0 ELSE pop10 * colleges_score / tmp_pop.tech END),
        regexp_replace('Average tech/vocational colleges score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this tech/vocational colleges score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- college pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Average college bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of tech/vocational colleges in the neighborhood expressed as an average of
            all colleges in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, colleges in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_colleges
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_colleges.geom_pt,b.geom)
        );

-- college pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Median tech/vocational college population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to tech/vocational colleges
            in the neighborhood to total population within the bike shed
            of each college expressed as a median of all
            colleges in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of tech/vocational colleges in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one tech/vocational college exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_colleges
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_colleges.geom_pt,b.geom)
        );

-- college pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '70th percentile tech/vocational college population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to tech/vocational colleges
            in the neighborhood to total population within the bike shed
            of each college expressed as the 70th percentile of all
            colleges in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of tech/vocational colleges in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one tech/vocational college exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_colleges
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_colleges.geom_pt,b.geom)
        );

-- college pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '30th percentile tech/vocational college population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to tech/vocational colleges
            in the neighborhood to total population within the bike shed
            of each college expressed as the 30th percentile of all
            colleges in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of tech/vocational colleges in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one tech/vocational college exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_colleges
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_colleges.geom_pt,b.geom)
        );


-------------------------------------
-- universities
-------------------------------------
-- average university access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Average score of low stress access to universities',
        CASE    WHEN SUM(universities_high_stress) = 0 THEN 0
                ELSE SUM(universities_low_stress) / SUM(universities_high_stress)
                END,
        regexp_replace('Number of universities accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many universities.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median universities access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Median score of university access',
        quantile(CASE WHEN universities_high_stress=0 THEN 0 ELSE universities_low_stress::FLOAT/universities_high_stress END,0.5),
        regexp_replace('Score of universities accessible by low stress
            compared to universities accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of universities within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile universities access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '70th percentile score of university access',
        quantile(CASE WHEN universities_high_stress=0 THEN 0 ELSE universities_low_stress::FLOAT/universities_high_stress END,0.7),
        regexp_replace('Score of universities accessible by low stress
            compared to universities accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of universities within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile universities access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '30th percentile score of university access',
        quantile(CASE WHEN universities_high_stress=0 THEN 0 ELSE universities_low_stress::FLOAT/universities_high_stress END,0.3),
        regexp_replace('Score of universities accessible by low stress
            compared to universities accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of universities within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_univ
)
SELECT  'Opportunity',
        'Average score of access to universities',
        SUM(CASE WHEN tmp_pop.univ = 0 THEN 0 ELSE pop10 * universities_score / tmp_pop.univ END),
        regexp_replace('Average universities score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this universities score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- university pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Average university bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of universities in the neighborhood expressed as an average of
            all universities in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, universities in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_universities
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_universities.geom_pt,b.geom)
        );

-- university pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        'Median university population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to universities
            in the neighborhood to total population within the bike shed
            of each university expressed as a median of all
            universities in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of universities in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one university exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_universities
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_universities.geom_pt,b.geom)
        );

-- university pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '70th percentile university population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to universities
            in the neighborhood to total population within the bike shed
            of each university expressed as the 70th percentile of all
            universities in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of universities in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one university exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_universities
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_universities.geom_pt,b.geom)
        );

-- university pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Opportunity',
        '30th percentile university population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to universities
            in the neighborhood to total population within the bike shed
            of each university expressed as the 30th percentile of all
            universities in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of universities in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one university exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_universities
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_universities.geom_pt,b.geom)
        );


-------------------------------------
-- doctors
-------------------------------------
-- average doctors access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average score of low stress access to doctors',
        CASE    WHEN SUM(doctors_high_stress) = 0 THEN 0
                ELSE SUM(doctors_low_stress) / SUM(doctors_high_stress)
                END,
        regexp_replace('Number of doctors accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many doctors.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median doctors access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median score of doctors access',
        quantile(CASE WHEN doctors_high_stress=0 THEN 0 ELSE doctors_low_stress::FLOAT/doctors_high_stress END,0.5),
        regexp_replace('Score of doctors accessible by low stress
            compared to doctors accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of doctors within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile doctors access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile score of doctors access',
        quantile(CASE WHEN doctors_high_stress=0 THEN 0 ELSE doctors_low_stress::FLOAT/doctors_high_stress END,0.7),
        regexp_replace('Score of doctors accessible by low stress
            compared to doctors accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of doctors within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile doctors access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile score of doctors access',
        quantile(CASE WHEN doctors_high_stress=0 THEN 0 ELSE doctors_low_stress::FLOAT/doctors_high_stress END,0.3),
        regexp_replace('Score of doctors accessible by low stress
            compared to doctors accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of doctors within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_doctor
)
SELECT  'Core Services',
        'Average score of access to doctors',
        SUM(CASE WHEN tmp_pop.doctor = 0 THEN 0 ELSE pop10 * doctors_score / tmp_pop.doctor END),
        regexp_replace('Average doctors score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this doctors score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- doctors pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average doctors bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of doctors in the neighborhood expressed as an average of
            all doctors in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, doctors in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_doctors
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_doctors.geom_pt,b.geom)
        );

-- doctors pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median doctors population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to doctors
            in the neighborhood to total population within the bike shed
            of each doctors office expressed as a median of all
            doctors in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of doctors in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one doctors office exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_doctors
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_doctors.geom_pt,b.geom)
        );

-- doctors pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile doctors population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to doctors
            in the neighborhood to total population within the bike shed
            of each doctors office expressed as the 70th percentile of all
            doctors in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of doctors in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one doctors exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_doctors
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_doctors.geom_pt,b.geom)
        );

-- doctors pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile doctors population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to doctors
            in the neighborhood to total population within the bike shed
            of each doctors office expressed as the 30th percentile of all
            doctors in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of doctors in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one doctors exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_doctors
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_doctors.geom_pt,b.geom)
        );

-------------------------------------
-- dentists
-------------------------------------
-- average dentists access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average score of low stress access to dentists',
        CASE    WHEN SUM(dentists_high_stress) = 0 THEN 0
                ELSE SUM(dentists_low_stress) / SUM(dentists_high_stress)
                END,
        regexp_replace('Number of dentists accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many dentists.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median dentists access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median score of dentists access',
        quantile(CASE WHEN dentists_high_stress=0 THEN 0 ELSE dentists_low_stress::FLOAT/dentists_high_stress END,0.5),
        regexp_replace('Score of dentists accessible by low stress
            compared to dentists accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of dentists within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile dentists access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile score of dentists access',
        quantile(CASE WHEN dentists_high_stress=0 THEN 0 ELSE dentists_low_stress::FLOAT/dentists_high_stress END,0.7),
        regexp_replace('Score of dentists accessible by low stress
            compared to dentists accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of dentists within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile dentists access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile score of dentists access',
        quantile(CASE WHEN dentists_high_stress=0 THEN 0 ELSE dentists_low_stress::FLOAT/dentists_high_stress END,0.3),
        regexp_replace('Score of dentists accessible by low stress
            compared to dentists accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of dentists within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_dentist
)
SELECT  'Core Services',
        'Average score of access to dentists',
        SUM(CASE WHEN tmp_pop.dentist = 0 THEN 0 ELSE pop10 * dentists_score / tmp_pop.dentist END),
        regexp_replace('Average dentists score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this dentists score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- dentists pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average dentists bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of dentists in the neighborhood expressed as an average of
            all dentists in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, dentists in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_dentists
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_dentists.geom_pt,b.geom)
        );

-- dentists pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median dentists population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to dentists
            in the neighborhood to total population within the bike shed
            of each dentists office expressed as a median of all
            dentists in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of dentists in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one dentists office exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_dentists
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_dentists.geom_pt,b.geom)
        );

-- dentists pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile dentists population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to dentists
            in the neighborhood to total population within the bike shed
            of each dentists office expressed as the 70th percentile of all
            dentists in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of dentists in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one dentists office exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_dentists
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_dentists.geom_pt,b.geom)
        );

-- dentists pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile dentists population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to dentists
            in the neighborhood to total population within the bike shed
            of each dentists office expressed as the 30th percentile of all
            dentists in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of dentists in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one dentists office exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_dentists
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_dentists.geom_pt,b.geom)
        );

-------------------------------------
-- hospitals
-------------------------------------
-- average hospitals access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average score of low stress access to hospitals',
        CASE    WHEN SUM(hospitals_high_stress) = 0 THEN 0
                ELSE SUM(hospitals_low_stress) / SUM(hospitals_high_stress)
                END,
        regexp_replace('Number of hospitals accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many hospitals.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median hospitals access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median score of hospitals access',
        quantile(CASE WHEN hospitals_high_stress=0 THEN 0 ELSE hospitals_low_stress::FLOAT/hospitals_high_stress END,0.5),
        regexp_replace('Score of hospitals accessible by low stress
            compared to hospitals accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of hospitals within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile hospitals access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile score of hospitals access',
        quantile(CASE WHEN hospitals_high_stress=0 THEN 0 ELSE hospitals_low_stress::FLOAT/hospitals_high_stress END,0.7),
        regexp_replace('Score of hospitals accessible by low stress
            compared to hospitals accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of hospitals within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile hospitals access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile score of hospitals access',
        quantile(CASE WHEN hospitals_high_stress=0 THEN 0 ELSE hospitals_low_stress::FLOAT/hospitals_high_stress END,0.3),
        regexp_replace('Score of hospitals accessible by low stress
            compared to hospitals accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of hospitals within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_hospital
)
SELECT  'Core Services',
        'Average score of access to hospitals',
        SUM(CASE WHEN tmp_pop.hospital = 0 THEN 0 ELSE pop10 * hospitals_score / tmp_pop.hospital END),
        regexp_replace('Average hospital score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this hospital score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- hospitals pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average hospitals bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of hospitals in the neighborhood expressed as an average of
            all hospitals in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, hospitals in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_hospitals
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_hospitals.geom_pt,b.geom)
        );

-- hospitals pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median hospitals population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to hospitals
            in the neighborhood to total population within the bike shed
            of each hospital expressed as a median of all
            hospitals in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of hospitals in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one hospital exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_hospitals
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_hospitals.geom_pt,b.geom)
        );

-- hospitals pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile hospitals population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to hospitals
            in the neighborhood to total population within the bike shed
            of each hospital expressed as the 70th percentile of all
            hospitals in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of hospitals in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one hospital exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_hospitals
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_hospitals.geom_pt,b.geom)
        );

-- hospitals pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile hospitals population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to hospitals
            in the neighborhood to total population within the bike shed
            of each hospital expressed as the 30th percentile of all
            hospitals in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of hospitals in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one hospital exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_hospitals
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_hospitals.geom_pt,b.geom)
        );

-------------------------------------
-- pharmacies
-------------------------------------
-- average pharmacies access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average score of low stress access to pharmacies',
        CASE    WHEN SUM(pharmacies_high_stress) = 0 THEN 0
                ELSE SUM(pharmacies_low_stress) / SUM(pharmacies_high_stress)
                END,
        regexp_replace('Number of pharmacies accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many pharmacies.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median pharmacies access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median score of pharmacies access',
        quantile(CASE WHEN pharmacies_high_stress=0 THEN 0 ELSE pharmacies_low_stress::FLOAT/pharmacies_high_stress END,0.5),
        regexp_replace('Score of pharmacies accessible by low stress
            compared to pharmacies accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of pharmacies within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile pharmacies access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile score of pharmacies access',
        quantile(CASE WHEN pharmacies_high_stress=0 THEN 0 ELSE pharmacies_low_stress::FLOAT/pharmacies_high_stress END,0.7),
        regexp_replace('Score of pharmacies accessible by low stress
            compared to pharmacies accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of pharmacies within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile pharmacies access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile score of pharmacies access',
        quantile(CASE WHEN pharmacies_high_stress=0 THEN 0 ELSE pharmacies_low_stress::FLOAT/pharmacies_high_stress END,0.3),
        regexp_replace('Score of pharmacies accessible by low stress
            compared to pharmacies accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of pharmacies within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_pharmacy
)
SELECT  'Core Services',
        'Average score of access to pharmacies',
        SUM(CASE WHEN tmp_pop.pharmacy = 0 THEN 0 ELSE pop10 * pharmacies_score / tmp_pop.pharmacy END),
        regexp_replace('Average pharmacies score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this pharmacies score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- pharmacies pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average pharmacies bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of pharmacies in the neighborhood expressed as an average of
            all pharmacies in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, pharmacies in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_pharmacies
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_pharmacies.geom_pt,b.geom)
        );

-- pharmacies pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median pharmacies population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to pharmacies
            in the neighborhood to total population within the bike shed
            of each pharmacy expressed as a median of all
            pharmacies in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of pharmacies in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one pharmacy exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_pharmacies
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_pharmacies.geom_pt,b.geom)
        );

-- pharmacies pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile pharmacies population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to pharmacies
            in the neighborhood to total population within the bike shed
            of each pharmacy expressed as the 70th percentile of all
            pharmacies in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of pharmacies in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one pharmacy exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_pharmacies
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_pharmacies.geom_pt,b.geom)
        );

-- pharmacies pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile pharmacies population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to pharmacies
            in the neighborhood to total population within the bike shed
            of each pharmacy expressed as the 30th percentile of all
            pharmacies in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of pharmacies in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one pharmacy exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_pharmacies
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_pharmacies.geom_pt,b.geom)
        );

-------------------------------------
-- retail
-------------------------------------
-- average retail access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        'Average score of low stress access to retail',
        CASE    WHEN SUM(retail_high_stress) = 0 THEN 0
                ELSE SUM(retail_low_stress) / SUM(retail_high_stress)
                END,
        regexp_replace('Number of retail accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many retail.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median retail access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        'Median score of retail access',
        quantile(CASE WHEN retail_high_stress=0 THEN 0 ELSE retail_low_stress::FLOAT/retail_high_stress END,0.5),
        regexp_replace('Score of retail accessible by low stress
            compared to retail accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of retail within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile retail access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        '70th percentile score of retail access',
        quantile(CASE WHEN retail_high_stress=0 THEN 0 ELSE retail_low_stress::FLOAT/retail_high_stress END,0.7),
        regexp_replace('Score of retail accessible by low stress
            compared to retail accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of retail within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile retail access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        '30th percentile score of retail access',
        quantile(CASE WHEN retail_high_stress=0 THEN 0 ELSE retail_low_stress::FLOAT/retail_high_stress END,0.3),
        regexp_replace('Score of retail accessible by low stress
            compared to retail accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of retail within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_retail
)
SELECT  'Retail',
        'Average score of access to retail',
        SUM(CASE WHEN tmp_pop.retail = 0 THEN 0 ELSE pop10 * retail_score / tmp_pop.retail END),
        regexp_replace('Average retail score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this retail score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- retail pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        'Average retail bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of retail clusters in the neighborhood expressed as an average of
            all retail clusters in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, retail clusters in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_retail
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_retail.geom_poly,b.geom)
        );

-- retail pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        'Median retail population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to retail
            in the neighborhood to total population within the bike shed
            of each retail cluster expressed as a median of all
            retail clusters in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of retail clusters in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one retail exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_retail
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_retail.geom_poly,b.geom)
        );

-- retail pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        '70th percentile retail population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to retail
            in the neighborhood to total population within the bike shed
            of each retail cluster expressed as the 70th percentile of all
            retail clusters in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of retail clusters in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one retail exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_retail
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_retail.geom_poly,b.geom)
        );

-- retail pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Retail',
        '30th percentile retail population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to retail
            in the neighborhood to total population within the bike shed
            of each retail cluster expressed as the 30th percentile of all
            retail clusters in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of retail clusters in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one retail exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_retail
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_retail.geom_poly,b.geom)
        );

-------------------------------------
-- supermarkets
-------------------------------------
-- average supermarkets access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average score of low stress access to supermarkets',
        CASE    WHEN SUM(supermarkets_high_stress) = 0 THEN 0
                ELSE SUM(supermarkets_low_stress) / SUM(supermarkets_high_stress)
                END,
        regexp_replace('Number of supermarkets accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many supermarkets.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median supermarkets access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median score of supermarkets access',
        quantile(CASE WHEN supermarkets_high_stress=0 THEN 0 ELSE supermarkets_low_stress::FLOAT/supermarkets_high_stress END,0.5),
        regexp_replace('Score of supermarkets accessible by low stress
            compared to supermarkets accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of supermarkets within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile supermarkets access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile score of supermarkets access',
        quantile(CASE WHEN supermarkets_high_stress=0 THEN 0 ELSE supermarkets_low_stress::FLOAT/supermarkets_high_stress END,0.7),
        regexp_replace('Score of supermarkets accessible by low stress
            compared to supermarkets accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of supermarkets within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile supermarkets access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile score of supermarkets access',
        quantile(CASE WHEN supermarkets_high_stress=0 THEN 0 ELSE supermarkets_low_stress::FLOAT/supermarkets_high_stress END,0.3),
        regexp_replace('Score of supermarkets accessible by low stress
            compared to supermarkets accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of supermarkets within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_grocery
)
SELECT  'Core Services',
        'Average score of access to grocery stores',
        SUM(CASE WHEN tmp_pop.grocery = 0 THEN 0 ELSE pop10 * supermarkets_score / tmp_pop.grocery END),
        regexp_replace('Average grocery score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this grocery score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- supermarkets pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average supermarkets bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of supermarkets in the neighborhood expressed as an average of
            all supermarkets in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, supermarkets in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_supermarkets
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_supermarkets.geom_pt,b.geom)
        );

-- supermarkets pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median supermarkets population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to supermarkets
            in the neighborhood to total population within the bike shed
            of each supermarket expressed as a median of all
            supermarkets in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of supermarkets in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one supermarkets exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_supermarkets
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_supermarkets.geom_pt,b.geom)
        );

-- supermarkets pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile supermarkets population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to supermarkets
            in the neighborhood to total population within the bike shed
            of each supermarket expressed as the 70th percentile of all
            supermarkets in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of supermarkets in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one supermarkets exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_supermarkets
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_supermarkets.geom_pt,b.geom)
        );

-- supermarkets pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile supermarkets population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to supermarkets
            in the neighborhood to total population within the bike shed
            of each supermarket expressed as the 30th percentile of all
            supermarkets in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of supermarkets in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one supermarkets exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_supermarkets
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_supermarkets.geom_pt,b.geom)
        );

-------------------------------------
-- social_services
-------------------------------------
-- average social_services access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average score of low stress access to social services',
        CASE    WHEN SUM(social_services_high_stress) = 0 THEN 0
                ELSE SUM(social_services_low_stress) / SUM(social_services_high_stress)
                END,
        regexp_replace('Number of social services accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many social services.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median social_services access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median score of social services access',
        quantile(CASE WHEN social_services_high_stress=0 THEN 0 ELSE social_services_low_stress::FLOAT/social_services_high_stress END,0.5),
        regexp_replace('Score of social services accessible by low stress
            compared to social services accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of social services within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile social_services access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile score of social services access',
        quantile(CASE WHEN social_services_high_stress=0 THEN 0 ELSE social_services_low_stress::FLOAT/social_services_high_stress END,0.7),
        regexp_replace('Score of social services accessible by low stress
            compared to social services accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of social services within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile social_services access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile score of social services access',
        quantile(CASE WHEN social_services_high_stress=0 THEN 0 ELSE social_services_low_stress::FLOAT/social_services_high_stress END,0.3),
        regexp_replace('Score of social services accessible by low stress
            compared to social services accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of social services within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_social_svcs
)
SELECT  'Core Services',
        'Average score of access to social services',
        SUM(CASE WHEN tmp_pop.social_svcs = 0 THEN 0 ELSE pop10 * social_services_score / tmp_pop.social_svcs END),
        regexp_replace('Average social services score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this social services score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- social_services pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Average social_services bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of social services in the neighborhood expressed as an average of
            all social services in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, social_services in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_social_services
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_social_services.geom_pt,b.geom)
        );

-- social_services pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        'Median social_services population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to social services
            in the neighborhood to total population within the bike shed
            of each social service location expressed as a median of all
            social services in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of social services in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one social_services exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_social_services
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_social_services.geom_pt,b.geom)
        );

-- social_services pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '70th percentile social_services population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to social services
            in the neighborhood to total population within the bike shed
            of each social service location expressed as the 70th percentile of all
            social services in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of social services in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one social_services exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_social_services
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_social_services.geom_pt,b.geom)
        );

-- social_services pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Core Services',
        '30th percentile social_services population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to social services
            in the neighborhood to total population within the bike shed
            of each social service location expressed as the 30th percentile of all
            social services in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of social services in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one social_services exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_social_services
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_social_services.geom_pt,b.geom)
        );

-------------------------------------
-- parks
-------------------------------------
-- average parks access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Average score of low stress access to parks',
        CASE    WHEN SUM(parks_high_stress) = 0 THEN 0
                ELSE SUM(parks_low_stress) / SUM(parks_high_stress)
                END,
        regexp_replace('Number of parks accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many parks.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median parks access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Median score of parks access',
        quantile(CASE WHEN parks_high_stress=0 THEN 0 ELSE parks_low_stress::FLOAT/parks_high_stress END,0.5),
        regexp_replace('Score of parks accessible by low stress
            compared to parks accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of parks within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile parks access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '70th percentile score of parks access',
        quantile(CASE WHEN parks_high_stress=0 THEN 0 ELSE parks_low_stress::FLOAT/parks_high_stress END,0.7),
        regexp_replace('Score of parks accessible by low stress
            compared to parks accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of parks within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile parks access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '30th percentile score of parks access',
        quantile(CASE WHEN parks_high_stress=0 THEN 0 ELSE parks_low_stress::FLOAT/parks_high_stress END,0.3),
        regexp_replace('Score of parks accessible by low stress
            compared to parks accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of parks within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_parks
)
SELECT  'Recreation',
        'Average score of access to parks',
        SUM(CASE WHEN tmp_pop.parks = 0 THEN 0 ELSE pop10 * parks_score / tmp_pop.parks END),
        regexp_replace('Average parks score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this parks score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- parks pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Average parks bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of parks in the neighborhood expressed as an average of
            all parks in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, parks in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_parks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_parks.geom_pt,b.geom)
        );

-- parks pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Median parks population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to parks
            in the neighborhood to total population within the bike shed
            of each parks expressed as a median of all
            parks in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of parks in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one parks exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_parks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_parks.geom_pt,b.geom)
        );

-- parks pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '70th percentile parks population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to parks
            in the neighborhood to total population within the bike shed
            of each parks expressed as the 70th percentile of all
            parks in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of parks in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one parks exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_parks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_parks.geom_pt,b.geom)
        );

-- parks pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '30th percentile parks population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to parks
            in the neighborhood to total population within the bike shed
            of each parks expressed as the 30th percentile of all
            parks in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of parks in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one parks exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_parks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_parks.geom_pt,b.geom)
        );

-------------------------------------
-- trails
-------------------------------------
-- average trails access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Average score of low stress access to trails',
        CASE    WHEN SUM(trails_high_stress) = 0 THEN 0
                ELSE SUM(trails_low_stress) / SUM(trails_high_stress)
                END,
        regexp_replace('Number of trails accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many trails.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median trails access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Median score of trails access',
        quantile(CASE WHEN trails_high_stress=0 THEN 0 ELSE trails_low_stress::FLOAT/trails_high_stress END,0.5),
        regexp_replace('Score of trails accessible by low stress
            compared to trails accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of trails within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile trails access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '70th percentile score of trails access',
        quantile(CASE WHEN trails_high_stress=0 THEN 0 ELSE trails_low_stress::FLOAT/trails_high_stress END,0.7),
        regexp_replace('Score of trails accessible by low stress
            compared to trails accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of trails within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile trails access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '30th percentile score of trails access',
        quantile(CASE WHEN trails_high_stress=0 THEN 0 ELSE trails_low_stress::FLOAT/trails_high_stress END,0.3),
        regexp_replace('Score of trails accessible by low stress
            compared to trails accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of trails within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_trails
)
SELECT  'Recreation',
        'Average score of access to trails',
        SUM(CASE WHEN tmp_pop.trails = 0 THEN 0 ELSE pop10 * trails_score / tmp_pop.trails END),
        regexp_replace('Average trails score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this trails score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );
-------------------------------------
-- community_centers
-------------------------------------
-- average community_centers access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Average score of low stress access to community centers',
        CASE    WHEN SUM(community_centers_high_stress) = 0 THEN 0
                ELSE SUM(community_centers_low_stress) / SUM(community_centers_high_stress)
                END,
        regexp_replace('Number of community centers accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many community centers.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median community centers access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Median score of community centers access',
        quantile(CASE WHEN community_centers_high_stress=0 THEN 0 ELSE community_centers_low_stress::FLOAT/community_centers_high_stress END,0.5),
        regexp_replace('Score of community centers accessible by low stress
            compared to community centers accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of community centers within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile community centers access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '70th percentile score of community centers access',
        quantile(CASE WHEN community_centers_high_stress=0 THEN 0 ELSE community_centers_low_stress::FLOAT/community_centers_high_stress END,0.7),
        regexp_replace('Score of community centers accessible by low stress
            compared to community centers accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of community centers within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile community centers access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '30th percentile score of community centers access',
        quantile(CASE WHEN community_centers_high_stress=0 THEN 0 ELSE community_centers_low_stress::FLOAT/community_centers_high_stress END,0.3),
        regexp_replace('Score of community centers accessible by low stress
            compared to community centers accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of community centers within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_comm_ctrs
)
SELECT  'Recreation',
        'Average score of access to community centers',
        SUM(CASE WHEN tmp_pop.comm_ctrs = 0 THEN 0 ELSE pop10 * community_centers_score / tmp_pop.comm_ctrs END),
        regexp_replace('Average community centers score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this community centers score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- community centers pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Average community centers bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of community centers in the neighborhood expressed as an average of
            all community centers in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, community centers in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_community_centers
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_community_centers.geom_pt,b.geom)
        );

-- community centers pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        'Median community centers population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to community centers
            in the neighborhood to total population within the bike shed
            of each community centers expressed as a median of all
            community centers in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of community centers in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one community centers exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_community_centers
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_community_centers.geom_pt,b.geom)
        );

-- community centers pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '70th percentile community centers population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to community centers
            in the neighborhood to total population within the bike shed
            of each community centers expressed as the 70th percentile of all
            community centers in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of community centers in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one community centers exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_community_centers
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_community_centers.geom_pt,b.geom)
        );

-- community centers pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Recreation',
        '30th percentile community centers population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to community centers
            in the neighborhood to total population within the bike shed
            of each community centers expressed as the 30th percentile of all
            community centers in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of community centers in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one community centers exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_community_centers
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_community_centers.geom_pt,b.geom)
        );

-------------------------------------
-- transit
-------------------------------------
-- average transit access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        'Average score of low stress access to transit',
        CASE    WHEN SUM(transit_high_stress) = 0 THEN 0
                ELSE SUM(transit_low_stress) / SUM(transit_high_stress)
                END,
        regexp_replace('Number of transit stations accessible by low stress
            expressed as an average of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood have
            low stress access to this many transit stations.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- median transit access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        'Median score of transit access',
        quantile(CASE WHEN transit_high_stress=0 THEN 0 ELSE transit_low_stress::FLOAT/transit_high_stress END,0.5),
        regexp_replace('Score of transit stations accessible by low stress
            compared to transit stations accessible by high stress
            expressed as the median of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of census blocks in this neighborhood
            have low stress access to a higher ratio of transit stations within
            biking distance, half have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 70th percentile transit access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        '70th percentile score of transit access',
        quantile(CASE WHEN transit_high_stress=0 THEN 0 ELSE transit_low_stress::FLOAT/transit_high_stress END,0.7),
        regexp_replace('Score of transit stations accessible by low stress
            compared to transit stations accessible by high stress
            expressed as the 70th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of census blocks in this neighborhood
            have low stress access to a higher ratio of transit stations within
            biking distance, 70% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- 30th percentile transit access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        '30th percentile score of transit access',
        quantile(CASE WHEN transit_high_stress=0 THEN 0 ELSE transit_low_stress::FLOAT/transit_high_stress END,0.3),
        regexp_replace('Score of transit stations accessible by low stress
            compared to transit stations accessible by high stress
            expressed as the 30th percentile of all census blocks in the
            neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of census blocks in this neighborhood
            have low stress access to a higher ratio of transit stations within
            biking distance, 30% have access to a lower ratio.','\n\s+',' ','g')
FROM    neighborhood_census_blocks
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- population weighted census block score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation, use_transit
)
SELECT  'Transit',
        'Average score of access to transit',
        SUM(CASE WHEN tmp_pop.transit = 0 THEN 0 ELSE pop10 * transit_score / tmp_pop.transit END),
        regexp_replace('Average transit score for census blocks
            weighted by population.','\n\s+',' ','g'),
        regexp_replace('On average, census blocks in the neighborhood received
            this transit score.','\n\s+',' ','g'),
        True
FROM    neighborhood_census_blocks,
        tmp_pop
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- transit pop shed average low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        'Average transit bike shed access score',
        CASE    WHEN SUM(pop_high_stress) = 0 THEN 0
                ELSE SUM(pop_low_stress)::FLOAT / SUM(pop_high_stress)
                END,
        regexp_replace('Score of population with low stress access
            compared to total population within the bike shed distance
            of transit stations in the neighborhood expressed as an average of
            all transit stations in the neighborhood','\n\s+',' ','g'),
        regexp_replace('On average, transit stations in the neighborhood are
            connected by the low stress access to this percentage people
            within biking distance.','\n\s+',' ','g')
FROM    neighborhood_transit
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_transit.geom_pt,b.geom)
        );

-- transit pop shed median low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        'Median transit population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.5),
        regexp_replace('Score of population with low stress access to transit stations
            in the neighborhood to total population within the bike shed
            of each transit stations expressed as a median of all
            transit stations in the neighborhood','\n\s+',' ','g'),
        regexp_replace('Half of transit stations in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, half are connected to a lower percentage.
            (if only one transit station exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_transit
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_transit.geom_pt,b.geom)
        );

-- transit pop shed 70th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        '70th percentile transit population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.7),
        regexp_replace('Score of population with low stress access to transit stations
            in the neighborhood to total population within the bike shed
            of each transit stations expressed as the 70th percentile of all
            transit stations in the neighborhood','\n\s+',' ','g'),
        regexp_replace('30% of transit stations in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 70% are connected to a lower percentage.
            (if only one transit station exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_transit
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_transit.geom_pt,b.geom)
        );

-- transit pop shed 30th percentile low stress access score
INSERT INTO generated.neighborhood_score_inputs (
    category, score_name, score, notes, human_explanation
)
SELECT  'Transit',
        '30th percentile transit population shed score',
        quantile(CASE WHEN pop_high_stress=0 THEN 0 ELSE pop_low_stress::FLOAT/pop_high_stress END,0.3),
        regexp_replace('Score of population with low stress access to transit stations
            in the neighborhood to total population within the bike shed
            of each transit stations expressed as the 30th percentile of all
            transit stations in the neighborhood','\n\s+',' ','g'),
        regexp_replace('70% of transit stations in the neighborhood have low stress
            connections to a higher percentage of people within biking
            distance, 30% are connected to a lower percentage.
            (if only one transit station exists this is the score for that one
            location)','\n\s+',' ','g')
FROM    neighborhood_transit
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_transit.geom_pt,b.geom)
        );
