-- EX 603 Unit 4, Task 4.2: Build the breakdown leadership asked for
-- Database: ex603_data (loaded from movies.sql)
-- Failure state for this theme: a spam withdrawal, meaning a rating whose
-- rating_status is withdrawn and whose withdrawn_reason is Spam detected.
-- Producers are reported by movie_id, not by title.


-- Part A: Two numbers in one pass

-- 4.2A Requirement: CASE inside an aggregate, no WHERE on the whole query.
-- Question: for each movie, how many ratings did it receive and how many of
-- those were spam withdrawals?
-- Ratings with no withdrawn_reason make the CASE condition UNKNOWN instead of
-- TRUE. Those ratings are still handled correctly, because the ELSE 0 counts
-- them as not spam and they still count toward total_ratings.
SELECT
    movie_id,
    COUNT(*) AS total_ratings,
    SUM(CASE WHEN rating_status = 'withdrawn'
              AND withdrawn_reason = 'Spam detected'
             THEN 1 ELSE 0 END) AS spam_withdrawals,
    ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn'
                            AND withdrawn_reason = 'Spam detected'
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS spam_pct
FROM ratings
GROUP BY movie_id
ORDER BY spam_withdrawals DESC, spam_pct DESC, movie_id;
-- Result: 13 rows and 12 spam withdrawals in total, which matches the 12 from
-- Unit 3. Movie 2 is the highest with 3 of 16 (18.8 percent), then movie 3
-- with 2 of 13 (15.4 percent). Movie 4 has 1 of 6 (16.7 percent), but 6
-- ratings is too few to read anything into. Four movies (5, 8, 10 and 13) have
-- none, and the other seven (1, 4, 6, 7, 9, 11 and 12) have exactly one.


-- Part B: Subtotals and a grand total

-- 4.2B Requirement: GROUP BY ROLLUP, no detail rows.
-- Question: for each region, how many ratings and spam withdrawals are there
-- in total, and what are the platform-wide totals?
-- ROLLUP (device_country, rating_status) builds three levels: one row per
-- region and status (detail), one row per region (subtotal), and one row for
-- everything (grand total). GROUPING(rating_status) = 1 marks the rows where
-- the status was rolled up, so the HAVING keeps the subtotal and grand total
-- rows and drops the detail rows.
-- device_country is the region, as in 4.1d.
SELECT
    CASE WHEN GROUPING(device_country) = 1
         THEN 'All regions' ELSE device_country END AS region,
    CASE WHEN GROUPING(device_country) = 1
         THEN 'Grand total' ELSE 'Region subtotal' END AS row_type,
    COUNT(*) AS total_ratings,
    SUM(CASE WHEN rating_status = 'withdrawn'
              AND withdrawn_reason = 'Spam detected'
             THEN 1 ELSE 0 END) AS spam_withdrawals,
    ROUND(100.0 * SUM(CASE WHEN rating_status = 'withdrawn'
                            AND withdrawn_reason = 'Spam detected'
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS spam_pct
FROM ratings
GROUP BY ROLLUP (device_country, rating_status)
HAVING GROUPING(rating_status) = 1
ORDER BY GROUPING(device_country), device_country;
-- Result: 6 rows. The first five are the Region subtotal rows (Brazil, India,
-- UK, US, Vietnam) and the last row, labelled All regions, is the Grand total
-- with 200 ratings and 12 spam withdrawals (6.0 percent). The five region
-- subtotals add up to the grand total. India has the highest spam rate, 4 of
-- 40 (10.0 percent), and Vietnam and UK the lowest, 1 of 43 and 1 of 40.


-- Part C: A two-step pipeline

-- 4.2C-1 Requirement: WITH clause plus a second aggregation.
-- Question: among movies with enough volume to judge (at least 10 ratings,
-- the same threshold as 4.1c), what is the baseline spam rate?
-- Step 1 summarizes every movie. Step 2 aggregates that summary over the
-- high-volume movies. I report two baselines because they answer different
-- things. pooled_spam_pct treats the high-volume ratings as one group, so
-- busy movies weigh more. avg_of_movie_rates gives every movie the same weight.
WITH movie_summary AS (
    SELECT
        movie_id,
        COUNT(*) AS total_ratings,
        SUM(CASE WHEN rating_status = 'withdrawn'
                  AND withdrawn_reason = 'Spam detected'
                 THEN 1 ELSE 0 END) AS spam_withdrawals
    FROM ratings
    GROUP BY movie_id
)
SELECT
    COUNT(*)                                                    AS high_volume_movies,
    SUM(total_ratings)                                          AS ratings_covered,
    SUM(spam_withdrawals)                                       AS spam_withdrawals,
    ROUND(100.0 * SUM(spam_withdrawals) / SUM(total_ratings), 2) AS pooled_spam_pct,
    ROUND(AVG(100.0 * spam_withdrawals / total_ratings), 2)     AS avg_of_movie_rates,
    ROUND(MIN(100.0 * spam_withdrawals / total_ratings), 2)     AS lowest_movie_rate,
    ROUND(MAX(100.0 * spam_withdrawals / total_ratings), 2)     AS highest_movie_rate
FROM movie_summary
WHERE total_ratings >= 10;
-- Result: 12 movies cover 194 ratings and 11 spam withdrawals, so the pooled
-- baseline is 5.67 percent. The average of the 12 movie rates is 6.07 percent.
-- Rates run from 0 to 18.75 percent. Movie 4 is left out of the baseline
-- because it has only 6 ratings.

-- 4.2C-2 Requirement: WITH clause, second step filters and compares.
-- Question: which high-volume movies sit above that baseline, and by how
-- much?
WITH movie_summary AS (
    SELECT
        movie_id,
        COUNT(*) AS total_ratings,
        SUM(CASE WHEN rating_status = 'withdrawn'
                  AND withdrawn_reason = 'Spam detected'
                 THEN 1 ELSE 0 END) AS spam_withdrawals
    FROM ratings
    GROUP BY movie_id
),
baseline AS (
    SELECT 100.0 * SUM(spam_withdrawals) / SUM(total_ratings) AS pooled_spam_pct
    FROM movie_summary
    WHERE total_ratings >= 10
)
SELECT
    m.movie_id,
    m.total_ratings,
    m.spam_withdrawals,
    ROUND(100.0 * m.spam_withdrawals / m.total_ratings, 1)                      AS spam_pct,
    ROUND(b.pooled_spam_pct, 1)                                                 AS baseline_pct,
    ROUND(100.0 * m.spam_withdrawals / m.total_ratings - b.pooled_spam_pct, 1)  AS points_above_baseline
FROM movie_summary m
CROSS JOIN baseline b
WHERE m.total_ratings >= 10
  AND 100.0 * m.spam_withdrawals / m.total_ratings > b.pooled_spam_pct
ORDER BY points_above_baseline DESC, m.movie_id;
-- Result: 6 of the 12 high-volume movies sit above the 5.7 percent baseline.
-- Movie 2 is 13.1 points above (3 of 16) and movie 3 is 9.7 points above
-- (2 of 13). Movie 1 is 3.4 points above, and movies 9, 11 and 12 are within
-- 1.5 points, each with a single spam withdrawal, which is too close to the
-- baseline to count as different. The other six movies are at or below it.
