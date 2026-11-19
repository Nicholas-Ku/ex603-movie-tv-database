-- EX 603 Unit 6, Task 6.1: Compute across a window without collapsing
-- Database: ex603_data (loaded from movies.sql)
-- Question: is a rating unusual for its own movie, and when movies tie on
-- rating count, how do the ranking functions and NTILE decide their order?
-- Producers are movies, events are ratings, and the metric is ratings.score.
-- Producers are reported by movie_id.


-- Part A: Compare each event to its producer's average

-- 6.1A-1 Requirement: AVG(...) OVER (PARTITION BY ...).
-- Question: for every rating, what is its movie's average score, and how far
-- is the rating from it?
-- The window keeps all 200 ratings. Each row gains its movie's average and
-- rating count, computed over that movie's partition only.
-- movie_rating_count is there to check the partition sizes, as suggested by
-- the Unit 6 case study (validate what rows the calculation saw).
SELECT
    r.rating_id,
    r.movie_id,
    r.rated_at,
    r.rating_status,
    r.score,
    ROUND(AVG(r.score) OVER (PARTITION BY r.movie_id), 2) AS movie_avg_score,
    ROUND(r.score - AVG(r.score) OVER (PARTITION BY r.movie_id), 2) AS diff_from_movie_avg,
    COUNT(*) OVER (PARTITION BY r.movie_id) AS movie_rating_count
FROM ratings r
ORDER BY r.movie_id, r.rated_at, r.rating_id;
-- Result: 200 rows, one for every rating. Each row keeps its own score and
-- also carries its movie's average. The differences run from -3.01 to +2.91
-- points. movie_rating_count matches the per-movie counts from Unit 4, from 6
-- (movie 4) to 21 (movie 6).

-- 6.1A-2 Requirement: the GROUP BY version.
-- Question: what is each movie's average score?
SELECT
    movie_id,
    COUNT(*) AS rating_count,
    ROUND(AVG(score), 2) AS movie_avg_score
FROM ratings
GROUP BY movie_id
ORDER BY movie_id;
-- Result: 13 rows, one for every movie with ratings. Averages run from 2.09
-- (movie 11) to 3.51 (movie 5). The individual ratings are gone, so this
-- cannot say which ratings sit far from their movie's average.

-- 6.1A-3 Requirement: compare the two versions.
-- Question: how many rows does each version return, and do they agree on
-- every movie's average and count?
-- win reduces the window output to one row per movie with DISTINCT. grp is
-- the GROUP BY output. If the two agree, every movie matches and
-- movies_that_differ is 0.
WITH win AS (
    SELECT DISTINCT
        movie_id,
        AVG(score) OVER (PARTITION BY movie_id) AS avg_window,
        COUNT(*)   OVER (PARTITION BY movie_id) AS n_window
    FROM ratings
),
grp AS (
    SELECT movie_id, AVG(score) AS avg_group, COUNT(*) AS n_group
    FROM ratings
    GROUP BY movie_id
)
SELECT
    (SELECT COUNT(*) FROM ratings) AS window_version_rows,
    (SELECT COUNT(*) FROM grp)     AS group_by_version_rows,
    COUNT(*) AS movies_matched,
    COUNT(*) FILTER (WHERE w.avg_window <> g.avg_group
                        OR w.n_window <> g.n_group) AS movies_that_differ
FROM win w
INNER JOIN grp g ON g.movie_id = w.movie_id;
-- Result: the window version returns 200 rows and the GROUP BY version
-- returns 13. All 13 movies match, and 0 differ on average or count, so the
-- two versions compute the same averages. What GROUP BY loses is the 200
-- individual ratings, along with every column that describes them (status,
-- timestamp, score).

-- 6.1A-4 Requirement: a question that needs each row next to its group average.
-- Question: which ratings sit more than 2 points below their own movie's
-- average, and what status are they in?
-- A WHERE cannot filter on a window result in the same query, because the
-- window runs after WHERE. The window goes in a CTE and the filter goes in
-- the outer query.
WITH scored AS (
    SELECT
        r.rating_id,
        r.movie_id,
        r.rating_status,
        r.withdrawn_reason,
        r.score,
        AVG(r.score) OVER (PARTITION BY r.movie_id) AS movie_avg_score
    FROM ratings r
)
SELECT
    rating_status,
    withdrawn_reason,
    COUNT(*) AS ratings_far_below_avg
FROM scored
WHERE score < movie_avg_score - 2
GROUP BY rating_status, withdrawn_reason
ORDER BY ratings_far_below_avg DESC;
-- Result: 25 ratings sit more than 2 points below their movie's average. 20
-- are withdrawn (7 spam, 5 policy violation, 5 duplicate, 3 user request),
-- which fits the Unit 4 finding that every withdrawn rating has a score of
-- 0.5. The other 5 are published ratings between 0.8 and 1.1, three of them
-- on movie 10 (ratings 141, 144 and 145). Those three are the ones a
-- reviewer could actually learn something from.


-- Part B: Rank producers three ways

-- 6.1B Requirement: ROW_NUMBER(), RANK() and DENSE_RANK() side by side.
-- Question: if leadership publishes a leaderboard of movies by number of
-- ratings, where does each movie land under each ranking method?
-- The LEFT JOIN keeps movies 14 and 15, which have no ratings (the Unit 5
-- finding). COUNT(r.rating_id) gives them 0 instead of 1.
-- Only ROW_NUMBER gets movie_id as a tiebreaker, so its order is the same on
-- every run. RANK and DENSE_RANK order by rating_count alone. Adding movie_id
-- to them would break the ties they are meant to show.
WITH movie_counts AS (
    SELECT m.movie_id, COUNT(r.rating_id) AS rating_count
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id
)
SELECT
    movie_id,
    rating_count,
    ROW_NUMBER() OVER (ORDER BY rating_count DESC, movie_id) AS row_number_pos,
    RANK()       OVER (ORDER BY rating_count DESC)           AS rank_pos,
    DENSE_RANK() OVER (ORDER BY rating_count DESC)           AS dense_rank_pos
FROM movie_counts
ORDER BY rating_count DESC, movie_id;
-- Result: 15 rows with four ties. Movies 5 and 7 both have 18 ratings.
-- ROW_NUMBER gives them 4 and 5, RANK gives both 4 and then skips to 6 for
-- movie 12, and DENSE_RANK gives both 4 and continues at 5. Movies 2 and 11
-- (16), 1 and 13 (11), and 14 and 15 (0) show the same pattern. By the
-- bottom, RANK ends at 14 and DENSE_RANK ends at 11, because DENSE_RANK
-- counts distinct rating counts, not movies.


-- Part C: Sort producers into four bands

-- 6.1C-1 Requirement: NTILE(4).
-- Question: if the 15 movies are split into four equal-sized bands by number
-- of ratings, which band does each movie land in?
-- NTILE splits by row count, not by value. 15 rows do not divide by 4, so
-- the extra rows go to the first bands and the sizes are 4, 4, 4 and 3.
-- movie_id breaks ties so the result is the same on every run.
WITH movie_counts AS (
    SELECT m.movie_id, COUNT(r.rating_id) AS rating_count
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id
)
SELECT
    movie_id,
    rating_count,
    NTILE(4) OVER (ORDER BY rating_count DESC, movie_id) AS volume_band
FROM movie_counts
ORDER BY rating_count DESC, movie_id;
-- Result: band 1 is movies 6, 8, 10 and 5. Band 2 is 7, 12, 2 and 11. Band 3
-- is 9, 3, 1 and 13. Band 4 is 4, 14 and 15. Movie 5 is in band 1 and movie
-- 7 is in band 2, even though both have 18 ratings.

-- 6.1C-2 Requirement: find tied producers on both sides of a band boundary.
-- Question: are any movies with the same rating count placed in different
-- bands?
WITH movie_counts AS (
    SELECT m.movie_id, COUNT(r.rating_id) AS rating_count
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id
),
banded AS (
    SELECT
        movie_id,
        rating_count,
        NTILE(4) OVER (ORDER BY rating_count DESC, movie_id) AS volume_band
    FROM movie_counts
)
SELECT
    rating_count,
    STRING_AGG(movie_id || ' (band ' || volume_band || ')', ', '
               ORDER BY movie_id) AS movies_and_bands
FROM banded
GROUP BY rating_count
HAVING COUNT(DISTINCT volume_band) > 1
ORDER BY rating_count DESC;
-- Result: 1 row. Movies 5 and 7, tied at 18 ratings, are split between band
-- 1 and band 2. The boundary falls after the fourth row, and movie_id is the
-- only thing that put movie 5 first. The other ties (16, 11 and 0) happen to
-- fall inside a single band. If the bands are meant to say something about
-- volume, CASE WHEN on rating_count would keep tied movies together, because
-- it bands by value and not by row position.
