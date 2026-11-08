-- EX 603 Unit 5, Task 5.3: Understand join performance and execution plans
-- Database: ex603_data (loaded from movies.sql)
-- Everything here is read-only, so EXPLAIN ANALYZE is safe to run.


-- Part A: CROSS JOIN

-- 5.3A-1 Requirement: CROSS JOIN between two small tables.
-- Question: what does every genre paired with every movie look like?
-- genres has 5 rows and movies has 15 rows. A CROSS JOIN has no ON clause,
-- because every row of one table pairs with every row of the other. The
-- full result has 75 rows, so the LIMIT only keeps the output short enough
-- to read. 5.3A-2 counts all of them.
SELECT g.genre_id, g.genre_name, m.movie_id, m.title
FROM genres g
CROSS JOIN movies m
ORDER BY g.genre_id, m.movie_id
LIMIT 20;
-- Result: 20 of the 75 rows. Every movie appears with Drama (genre 1), then
-- every movie appears with Sci-Fi (genre 2), and so on. Each genre repeats
-- once for every movie, and each movie repeats once for every genre.

-- 5.3A-2 Requirement: source row counts, result row count, and the
-- multiplication check.
-- Question: does the CROSS JOIN return genres times movies rows?
SELECT
    (SELECT COUNT(*) FROM genres) AS genre_rows,
    (SELECT COUNT(*) FROM movies) AS movie_rows,
    (SELECT COUNT(*) FROM genres)
      * (SELECT COUNT(*) FROM movies) AS expected_rows,
    (SELECT COUNT(*) FROM genres g CROSS JOIN movies m) AS cross_join_rows,
    (SELECT COUNT(*) FROM genres)
      * (SELECT COUNT(*) FROM movies)
      = (SELECT COUNT(*) FROM genres g CROSS JOIN movies m) AS counts_match;
-- Result: 5 genre rows and 15 movie rows, so 5 x 15 = 75 expected, and the
-- CROSS JOIN returns 75. counts_match is true.

-- 5.3A-3 Requirement: a CROSS JOIN used for a purpose.
-- Question: of all possible movie and genre pairs, how many are tagged and
-- how many are not?
-- The CROSS JOIN builds every possible pair, and the LEFT JOIN to
-- movie_genres matches the pairs that exist as tags. COUNT(mg.movie_id)
-- counts only the matched pairs, because an unmatched pair has NULL there.
SELECT
    COUNT(*)                       AS all_pairs,
    COUNT(mg.movie_id)             AS tagged_pairs,
    COUNT(*) - COUNT(mg.movie_id)  AS untagged_pairs
FROM genres g
CROSS JOIN movies m
LEFT JOIN movie_genres mg
       ON mg.genre_id = g.genre_id
      AND mg.movie_id = m.movie_id;
-- Result: 75 possible pairs, 25 of them tagged and 50 not. The 25 tagged pairs
-- are the 25 rows of movie_genres, so the count agrees with that table.

-- 5.3A-4 Requirement: a CROSS JOIN used for a purpose.
-- Question: how many ratings does each genre receive from each country, with
-- every genre and country combination shown even if the count is 0?
-- The platform has no table of countries, so device_countries is the list of
-- distinct device_country values in ratings. The CROSS JOIN builds the full
-- grid first, and the LEFT JOINs fill in the counts. A rating of a movie with several genres counts once under each of
-- its genres, so the 25 counts add up to more than 200 and cannot be summed
-- into a platform total.
WITH device_countries AS (
    SELECT DISTINCT device_country FROM ratings
)
SELECT
    g.genre_name,
    d.device_country,
    COUNT(r.rating_id) AS ratings
FROM genres g
CROSS JOIN device_countries d
LEFT JOIN movie_genres mg ON mg.genre_id = g.genre_id
LEFT JOIN ratings r
       ON r.movie_id = mg.movie_id
      AND r.device_country = d.device_country
GROUP BY g.genre_name, d.device_country
ORDER BY g.genre_name, d.device_country;
-- Result: 25 rows, one for every genre and country pair. None of them is 0 in
-- this data. The lowest is Documentary with the UK at 2 ratings and the
-- highest is Drama with Brazil, the UK and Vietnam at 30 each. The counts add
-- up to 385, which is more than 200 because a rating is counted once for each
-- genre its movie carries, and movie 13 has no genre so its ratings are not
-- counted at all.


-- Part B: Execution plan for the three-table join from 5.1A

-- 5.3B-1 Requirement: EXPLAIN on the 5.1A query, character for character.
-- Question: how does PostgreSQL plan to run the three-table join?
-- EXPLAIN shows the plan and the estimates without running the query.
EXPLAIN
SELECT
    r.rating_id,
    u.user_name AS actor,
    m.movie_id,
    m.title     AS producer,
    r.rated_at
FROM ratings r
JOIN users  u ON u.user_id  = r.user_id
JOIN movies m ON m.movie_id = r.movie_id
ORDER BY r.rated_at DESC, r.rating_id DESC
LIMIT 20;
-- Result: The estimated plan, top to bottom: Limit, then Sort (top 20 by
-- rated_at), then a Nested Loop. Inside the Nested Loop, a Hash Join of
-- ratings and users (Seq Scan on ratings, Hash built from a Seq Scan on
-- users) feeds a Memoize node over an Index Scan using movies_pkey. The
-- planner expects 200 rows from the joins and a total cost of 33.71. It
-- estimates 100 rows for users, but the table holds 30.

-- 5.3B-2 Requirement: EXPLAIN ANALYZE on the same query.
-- Question: what did the plan actually do, and how long did it take?
-- EXPLAIN ANALYZE runs the query, which is safe here because it only reads.
-- It adds the real row counts and timings next to the estimates.
EXPLAIN ANALYZE
SELECT
    r.rating_id,
    u.user_name AS actor,
    m.movie_id,
    m.title     AS producer,
    r.rated_at
FROM ratings r
JOIN users  u ON u.user_id  = r.user_id
JOIN movies m ON m.movie_id = r.movie_id
ORDER BY r.rated_at DESC, r.rating_id DESC
LIMIT 20;
-- Result: Same plan as 5.3B-1, with actual numbers. The joins return the 200
-- rows that were expected. The hash table holds the 30 users in one batch
-- using 10kB. Memoize hits its cache 187 times and misses 13 times, which
-- matches the 13 movies that have ratings, so the index on movies is
-- searched only 13 times. The sort keeps only the top 20 rows (top-N
-- heapsort, 27kB). Planning Time is 6.272 ms and Execution Time is 0.252 ms
-- on the run in the screenshot, and the timings vary a little from run to run.
