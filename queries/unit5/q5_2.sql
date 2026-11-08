-- EX 603 Unit 5, Task 5.2: Find records that joins may exclude
-- Database: ex603_data (loaded from movies.sql)
-- Producers are movies and events are ratings. Producers are counted by
-- movie_id so a movie with many ratings is still one producer.


-- Part A: INNER JOIN compared with LEFT JOIN

-- 5.2A-1 Requirement: LEFT JOIN from producers to events.
-- Question: how many ratings does every producer have, including producers
-- with none?
-- movies is the left table, so every movie stays in the result. COUNT of
-- r.rating_id counts only real ratings, because the NULL row a LEFT JOIN
-- creates for an unmatched movie has no rating_id. COUNT(*) would show 1
-- for those movies instead of 0.
SELECT
    m.movie_id,
    m.title,
    m.is_available,
    COUNT(r.rating_id) AS total_ratings
FROM movies m
LEFT JOIN ratings r ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.is_available
ORDER BY m.movie_id;
-- Result: 15 rows, one for every movie. Movies 14 and 15 show 0 ratings.
-- The other 13 movies range from 6 ratings (movie 4) to 21 (movie 6).

-- 5.2A-2 Requirement: the equivalent INNER JOIN.
-- Question: the same report, but with an INNER JOIN, which producers appear?
SELECT
    m.movie_id,
    m.title,
    m.is_available,
    COUNT(r.rating_id) AS total_ratings
FROM movies m
INNER JOIN ratings r ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.is_available
ORDER BY m.movie_id;
-- Result: 13 rows. The numbers for movies 1 to 13 are identical to the
-- LEFT JOIN, and movies 14 and 15 are missing.

-- 5.2A-3 Requirement: count of producers excluded by the inner join.
-- Question: how many producers does the inner join drop?
-- DISTINCT movie_id is used on both sides so a producer with many ratings
-- is counted once. The LEFT JOIN side counts every producer and the INNER
-- JOIN side counts only producers that have at least one rating.
WITH left_side AS (
    SELECT DISTINCT m.movie_id
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
),
inner_side AS (
    SELECT DISTINCT m.movie_id
    FROM movies m
    INNER JOIN ratings r ON r.movie_id = m.movie_id
)
SELECT
    (SELECT COUNT(*) FROM left_side)  AS producers_left_join,
    (SELECT COUNT(*) FROM inner_side) AS producers_inner_join,
    (SELECT COUNT(*) FROM left_side)
      - (SELECT COUNT(*) FROM inner_side) AS producers_excluded;
-- Result: 15 producers with the LEFT JOIN, 13 with the INNER JOIN, so the
-- inner join excludes 2 producers.

-- 5.2A-4 Requirement: identify the excluded producers.
-- Question: which producers are missing from the inner join, and what do we
-- know about them?
-- WHERE r.rating_id IS NULL keeps only the movies that found no rating.
-- genre_tags counts the rows each movie has in movie_genres.
SELECT
    m.movie_id,
    m.title,
    m.release_year,
    m.added_on,
    m.origin_country,
    m.is_available,
    (SELECT COUNT(*) FROM movie_genres mg
      WHERE mg.movie_id = m.movie_id) AS genre_tags
FROM movies m
LEFT JOIN ratings r ON r.movie_id = m.movie_id
WHERE r.rating_id IS NULL
ORDER BY m.movie_id;
-- Result: 2 rows. Movies 14 (India, 2013) and 15 (UK, 2008) are the excluded
-- producers. Both are available, both were added in 2022, and neither has a
-- genre tag. The table shows that they have no ratings, but it does not show
-- why.


-- Part B: RIGHT JOIN and FULL OUTER JOIN

-- 5.2B-1 Requirement: RIGHT JOIN that returns the same records as 5.2A-1.
-- Question: if the tables are written in the opposite order, does a RIGHT
-- JOIN return every producer, including those with no ratings?
-- ratings is now the left table and movies is the right table, so the
-- RIGHT JOIN is the one that keeps every movie.
SELECT
    m.movie_id,
    m.title,
    m.is_available,
    COUNT(r.rating_id) AS total_ratings
FROM ratings r
RIGHT JOIN movies m ON r.movie_id = m.movie_id
GROUP BY m.movie_id, m.title, m.is_available
ORDER BY m.movie_id;
-- Result: 15 rows, with movies 14 and 15 at 0 ratings, the same as 5.2A-1.

-- 5.2B-2 Requirement: verify that the LEFT and RIGHT results match.
-- Question: do the two queries return the same rows, or do they only look
-- alike?
-- EXCEPT runs in both directions. If the results are identical, both
-- directions return 0 rows and the two row counts are equal.
WITH left_result AS (
    SELECT m.movie_id, m.title, m.is_available, COUNT(r.rating_id) AS total_ratings
    FROM movies m
    LEFT JOIN ratings r ON r.movie_id = m.movie_id
    GROUP BY m.movie_id, m.title, m.is_available
),
right_result AS (
    SELECT m.movie_id, m.title, m.is_available, COUNT(r.rating_id) AS total_ratings
    FROM ratings r
    RIGHT JOIN movies m ON r.movie_id = m.movie_id
    GROUP BY m.movie_id, m.title, m.is_available
)
SELECT
    (SELECT COUNT(*) FROM left_result)  AS left_rows,
    (SELECT COUNT(*) FROM right_result) AS right_rows,
    (SELECT COUNT(*) FROM (SELECT * FROM left_result
                           EXCEPT
                           SELECT * FROM right_result) x) AS in_left_only,
    (SELECT COUNT(*) FROM (SELECT * FROM right_result
                           EXCEPT
                           SELECT * FROM left_result) y) AS in_right_only;
-- Result: Both queries return 15 rows and EXCEPT finds 0 rows in either
-- direction, so the two results are identical.

-- 5.2B-3 Requirement: FULL OUTER JOIN.
-- Question: when every movie and every rating is kept, how many rows are
-- matched, how many are movies with no ratings, and how many are ratings
-- with no movie?
-- This joins the rows themselves and does not group them. Each row is
-- sorted into one of three kinds by checking which side is NULL.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN m.movie_id IS NOT NULL AND r.rating_id IS NOT NULL
             THEN 1 ELSE 0 END) AS matched_rows,
    SUM(CASE WHEN r.rating_id IS NULL THEN 1 ELSE 0 END) AS movies_without_ratings,
    SUM(CASE WHEN m.movie_id IS NULL THEN 1 ELSE 0 END)  AS ratings_without_movie
FROM movies m
FULL OUTER JOIN ratings r ON r.movie_id = m.movie_id;
-- Result: 202 rows in total. 200 are matched, which equals the 200 ratings,
-- and 2 are movies without ratings. 0 ratings are without a movie.

-- 5.2B-4 Requirement: FULL OUTER JOIN, unmatched rows only.
-- Question: which rows have nothing on the other side?
SELECT
    m.movie_id AS movie_id_from_movies,
    r.movie_id AS movie_id_from_ratings,
    r.rating_id
FROM movies m
FULL OUTER JOIN ratings r ON r.movie_id = m.movie_id
WHERE m.movie_id IS NULL OR r.rating_id IS NULL
ORDER BY m.movie_id, r.rating_id;
-- Result: 2 rows, movies 14 and 15, with nothing from the ratings side. No row
-- has a rating without a movie. The foreign key from ratings to movies is what
-- makes that second kind of row impossible, and this query confirms it.


-- Part C: Producers with no events, two ways

-- 5.2C-1 Requirement: NOT EXISTS.
-- Question: which producers have never had an event?
-- For each movie, the subquery looks for any rating. NOT EXISTS keeps the
-- movie only when none is found, and it can return any column of movies.
SELECT m.movie_id, m.title
FROM movies m
WHERE NOT EXISTS (
    SELECT 1
    FROM ratings r
    WHERE r.movie_id = m.movie_id
)
ORDER BY m.movie_id;
-- Result: 2 rows, movies 14 and 15.

-- 5.2C-2 Requirement: EXCEPT.
-- Question: which producers have never had an event?
-- EXCEPT takes every movie_id in movies and removes the ones that also
-- appear in ratings. It compares whole rows, so only the movie_id column
-- comes back unless the lists are made to match in other columns.
SELECT movie_id FROM movies
EXCEPT
SELECT movie_id FROM ratings
ORDER BY movie_id;
-- Result: 2 rows, movies 14 and 15.

-- 5.2C-3 Requirement: compare the two approaches.
-- Question: do NOT EXISTS and EXCEPT find the same producers?
WITH by_not_exists AS (
    SELECT m.movie_id
    FROM movies m
    WHERE NOT EXISTS (SELECT 1 FROM ratings r WHERE r.movie_id = m.movie_id)
),
by_except AS (
    SELECT movie_id FROM movies
    EXCEPT
    SELECT movie_id FROM ratings
)
SELECT
    (SELECT COUNT(*) FROM by_not_exists) AS not_exists_rows,
    (SELECT COUNT(*) FROM by_except)     AS except_rows,
    (SELECT COUNT(*) FROM (SELECT movie_id FROM by_not_exists
                           EXCEPT
                           SELECT movie_id FROM by_except) x) AS only_in_not_exists,
    (SELECT COUNT(*) FROM (SELECT movie_id FROM by_except
                           EXCEPT
                           SELECT movie_id FROM by_not_exists) y) AS only_in_except;
-- Result: Both approaches return 2 rows, and neither finds a producer the other
-- misses, so they identify the same producers. They differ in how they get
-- there. NOT EXISTS checks one movie at a time for a matching rating and can
-- return any column of movies. EXCEPT subtracts one list of movie_id values
-- from the other and returns only the columns that were selected.
