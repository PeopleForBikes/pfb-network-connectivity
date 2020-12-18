----------------------------------------
-- Input variables:
--      :max_score - Maximum score value
--      :step1 - First scoring step
--      :score1 - Score for first step
--      :step2 - Second scoring step
--      :score2 - Score for second step
--      :step3 - Third scoring step
--      :score3 - Score for third step
----------------------------------------

-- add basic job count for the census block to census blocks table
UPDATE neighborhood_census_blocks
SET     job_count = 
            SELECT employment.jobs 
            FROM neighborhood_census_block_jobs employment
            WHERE neighborhood_census_blocks.blockid10 = employment.blockid10

-- raw numbers
UPDATE  neighborhood_census_blocks
SET     emp_low_stress = (
            SELECT  SUM(blocks2.jobs)
            FROM    neighborhood_census_block_jobs blocks2
            WHERE   EXISTS (
                        SELECT  1
                        FROM    neighborhood_connected_census_blocks cb
                        WHERE   cb.source_blockid10 = neighborhood_census_blocks.blockid10
                        AND     cb.target_blockid10 = blocks2.blockid10
                        AND     cb.low_stress
            )
        ),
        emp_high_stress = (
            SELECT  SUM(blocks2.jobs)
            FROM    neighborhood_census_block_jobs blocks2
            WHERE   EXISTS (
                        SELECT  1
                        FROM    neighborhood_connected_census_blocks cb
                        WHERE   cb.source_blockid10 = neighborhood_census_blocks.blockid10
                        AND     cb.target_blockid10 = blocks2.blockid10
            )
        )
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- set score
UPDATE  neighborhood_census_blocks
SET     emp_score = CASE
                    WHEN emp_high_stress IS NULL THEN NULL
                    WHEN emp_high_stress = 0 THEN NULL
                    WHEN emp_low_stress = 0 THEN 0
                    WHEN emp_high_stress = emp_low_stress THEN :max_score
                    WHEN :step1 = 0 THEN :max_score * emp_low_stress::FLOAT / emp_high_stress
                    WHEN emp_low_stress::FLOAT / emp_high_stress = :step3 THEN :score3
                    WHEN emp_low_stress::FLOAT / emp_high_stress = :step2 THEN :score2
                    WHEN emp_low_stress::FLOAT / emp_high_stress = :step1 THEN :score1
                    WHEN emp_low_stress::FLOAT / emp_high_stress > :step3
                        THEN    :score3
                                + (:max_score - :score3)
                                * (
                                    (emp_low_stress::FLOAT / emp_high_stress - :step3)
                                    / (1 - :step3)
                                )
                    WHEN emp_low_stress::FLOAT / emp_high_stress > :step2
                        THEN    :score2
                                + (:score3 - :score2)
                                * (
                                    (emp_low_stress::FLOAT / emp_high_stress - :step2)
                                    / (:step3 - :step2)
                                )
                    WHEN emp_low_stress::FLOAT / emp_high_stress > :step1
                        THEN    :score1
                                + (:score2 - :score1)
                                * (
                                    (emp_low_stress::FLOAT / emp_high_stress - :step1)
                                    / (:step2 - :step1)
                                )
                    ELSE        :score1
                                * (
                                    (emp_low_stress::FLOAT / emp_high_stress)
                                    / :step1
                                )
                    END;
