-- EX 603 Unit 3, Task 3.2: Find the bug
-- Database: ex603_data (loaded from movies.sql)
-- Failure state for this theme: a spam withdrawal, meaning a rating whose
-- rating_status is withdrawn and whose withdrawn_reason is Spam detected.
-- Note: this file contains one query that fails on purpose (3.2B-1). Run it
-- with psql's default settings, not ON_ERROR_STOP, so the later queries run.


-- Part A: The rows that vanished
-- The nullable column is ratings.withdrawn_reason. The dataset already has
-- NULLs in it (166 rows), so I did not insert any.

-- 3.2A-1 The broken filter. Requirement: inequality predicate.
-- Question: how many ratings were withdrawn for a reason other than spam?
-- I wrote it the way someone would who expects every rating that is not a
-- spam withdrawal to come back.
SELECT COUNT(*) AS rows_returned
FROM ratings
WHERE withdrawn_reason != 'Spam detected';
-- Result: 22. I expected something close to 188, which is everything that is
-- not a spam withdrawal.

-- 3.2A-2 The rows it silently dropped. Requirement: IS NULL.
-- Question: how many ratings were left out because their reason is missing,
-- and do the two counts add up to the table total?
SELECT
    (SELECT COUNT(*) FROM ratings WHERE withdrawn_reason != 'Spam detected') AS returned,
    (SELECT COUNT(*) FROM ratings WHERE withdrawn_reason IS NULL) AS silently_omitted,
    (SELECT COUNT(*) FROM ratings WHERE withdrawn_reason != 'Spam detected')
        + (SELECT COUNT(*) FROM ratings WHERE withdrawn_reason IS NULL) AS returned_plus_omitted,
    (SELECT COUNT(*) FROM ratings) AS table_total;
-- Result: 22 returned and 166 omitted add up to 188, but the table holds 200.
-- The missing 12 are the spam withdrawals themselves, which the filter
-- correctly leaves out. Comparing against NULL gives UNKNOWN instead of TRUE,
-- so WHERE throws those 166 rows away without any warning.

-- 3.2A-3 The repair. Requirement: explicit IS NULL condition.
-- Question: how many ratings are not spam withdrawals, counting the ones
-- with no reason at all?
SELECT COUNT(*) AS rows_returned
FROM ratings
WHERE withdrawn_reason != 'Spam detected'
OR withdrawn_reason IS NULL;
-- Result: 188, which is the 200 total minus the 12 spam withdrawals.

-- 3.2A-4 The same repair written with COALESCE. Requirement: COALESCE.
-- Question: how many ratings are not spam withdrawals when a missing reason
-- is replaced with a placeholder before the comparison?
SELECT COUNT(*) AS rows_returned
FROM ratings
WHERE COALESCE(withdrawn_reason, 'none') != 'Spam detected';
-- Result: 188 again.


-- Part B: The alias that did not exist yet

-- 3.2B-1 The failing query. Requirement: alias in SELECT used in WHERE.
-- Question: which ratings have a weighted score above 6?
SELECT rating_id, score * weight AS weighted_score
FROM ratings
WHERE weighted_score > 6;
-- Error, copied from psql:
--   ERROR:  column "weighted_score" does not exist
--   LINE 3: WHERE weighted_score > 6;
-- PostgreSQL evaluates WHERE before SELECT, so the alias is not defined yet.

-- 3.2B-2 Rewrite one: repeat the expression in WHERE.
-- Requirement: a correct rewrite of the alias query.
-- Question: which ratings have a weighted score above 6, using the full
-- expression in WHERE instead of the alias?
SELECT rating_id, score * weight AS weighted_score
FROM ratings
WHERE score * weight > 6
ORDER BY weighted_score DESC, rating_id;

-- 3.2B-3 Rewrite two: wrap the query in a CTE so the alias becomes a column.
-- Requirement: CTE. Question: which ratings have a weighted score above 6,
-- with the alias defined first so WHERE can use it?
WITH scored AS (
    SELECT rating_id, score * weight AS weighted_score
    FROM ratings
)
SELECT rating_id, weighted_score
FROM scored
WHERE weighted_score > 6
ORDER BY weighted_score DESC, rating_id;
-- Result: both rewrites return the same 35 rows. Scores run up to 5.0 and
-- weights up to 2.0, so the largest weighted score is 10.
