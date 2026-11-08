-- EX 603 Unit 5, Task 5.1: Connect producers to their data
-- Database: ex603_data (loaded from movies.sql)
-- Roles: actor = users, producer = movies, event = ratings, catalog = genres,
-- junction = movie_genres. Producers are reported by movie_id, with the title
-- beside it. The two producers Assignment 4 flagged are movies 2 and 3.


-- Part A: Who is behind each event?

-- 5.1A Requirement: three-table INNER JOIN.
-- Question: for the most recent ratings, which user rated which movie, and
-- when?
-- Every rating has a user and a movie because both foreign keys are NOT NULL,
-- so the INNER JOINs cannot drop a rating. 5.1A-check proves that below. The
-- LIMIT only keeps the output short enough to read, and the join itself is
-- the same one that 5.3 sends to EXPLAIN.
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
-- Result: 20 rows, newest first. The latest rating is rating 32, User_13 rating
-- Title_03 (movie 3) on 2023-12-28. Every row shows a named actor and a
-- named producer, and the 20 rows span 2023-11-18 to 2023-12-28.

-- 5.1A-check Requirement: confirm the join kept every rating.
-- Question: does the three-table join return as many rows as the ratings
-- table holds?
SELECT
    (SELECT COUNT(*) FROM ratings) AS ratings_rows,
    COUNT(*)                       AS joined_rows
FROM ratings r
JOIN users  u ON u.user_id  = r.user_id
JOIN movies m ON m.movie_id = r.movie_id;
-- Result: 200 ratings and 200 joined rows, so the inner joins lost nothing.


-- Part B: Do the flagged producers share a catalog tag?

-- 5.1B-1 Requirement: movies to genres through the junction table.
-- Question: which producers carry the Comedy tag, and are the Assignment 4
-- producers among them?
-- movie_genres holds one row per movie and genre pair, so the join goes
-- movies -> movie_genres -> genres. The assignment4_outlier column marks
-- movies 2 and 3.
SELECT
    m.movie_id,
    m.title,
    m.release_year,
    g.genre_name,
    mg.tagged_on,
    CASE WHEN m.movie_id IN (2, 3) THEN 'Yes' ELSE 'No' END AS assignment4_outlier
FROM movies m
JOIN movie_genres mg ON mg.movie_id = m.movie_id
JOIN genres g        ON g.genre_id  = mg.genre_id
WHERE g.genre_name = 'Comedy'
ORDER BY m.movie_id;
-- Result: 5 rows. Movies 2, 3, 5, 10 and 11 carry the Comedy tag. Both
-- Assignment 4 producers (movies 2 and 3) are on the list, along with movie 5
-- from the same release year and movies 10 and 11 from other years.

-- 5.1B-2 Requirement: same junction traversal, grouped by tag.
-- Question: which genres do movies 2 and 3 carry, and does any genre appear
-- on both?
-- COUNT(DISTINCT m.movie_id) counts the flagged movies behind each genre. A
-- value of 2 means both flagged movies carry that tag.
SELECT
    g.genre_name,
    COUNT(DISTINCT m.movie_id) AS flagged_movies_with_tag
FROM movies m
JOIN movie_genres mg ON mg.movie_id = m.movie_id
JOIN genres g        ON g.genre_id  = mg.genre_id
WHERE m.movie_id IN (2, 3)
GROUP BY g.genre_name
ORDER BY flagged_movies_with_tag DESC, g.genre_name;
-- Result: 4 rows. Comedy is the only genre that both flagged movies carry
-- (2 of 2). Drama and Thriller belong to movie 2 alone, and Sci-Fi to movie 3
-- alone. With only two movies and five genres in the catalog, sharing one tag
-- is not strong evidence of anything. Comedy is on 5 of the 15 movies.


-- Part C: How do producers compare with each other?

-- 5.1C Requirement: self join on the producer table.
-- Question: for every pair of movies released in the same year, how do their
-- rating counts and spam rates compare?
-- movies is joined to itself on release_year. a.movie_id < b.movie_id keeps
-- each pair once and stops a movie from pairing with itself. The activity
-- numbers come from a summary of ratings, joined with LEFT JOIN so a movie
-- with no ratings still appears, with a count of 0 and no spam rate.
WITH movie_activity AS (
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
    a.release_year,
    a.movie_id                                           AS movie_a,
    b.movie_id                                           AS movie_b,
    COALESCE(x.total_ratings, 0)                         AS a_ratings,
    ROUND(100.0 * x.spam_withdrawals / x.total_ratings, 1) AS a_spam_pct,
    COALESCE(y.total_ratings, 0)                         AS b_ratings,
    ROUND(100.0 * y.spam_withdrawals / y.total_ratings, 1) AS b_spam_pct,
    CASE WHEN a.origin_country = b.origin_country
         THEN 'Yes' ELSE 'No' END                        AS same_country
FROM movies a
JOIN movies b
  ON b.release_year = a.release_year
 AND a.movie_id < b.movie_id
LEFT JOIN movie_activity x ON x.movie_id = a.movie_id
LEFT JOIN movie_activity y ON y.movie_id = b.movie_id
ORDER BY a.release_year, a.movie_id, b.movie_id;
-- Result: 15 pairs from 5 release years that have at least two movies. The 2023
-- group holds movies 1 to 5, which is 10 of the 15 pairs. Four of those five
-- movies have a spam rate of 9.1 percent or more (movies 1, 2, 3 and 4), and
-- movie 5 has none. Movies 2 and 3 are the same-year pair with the two
-- highest rates among the movies with at least 10 ratings. Movie 4 sits at
-- 16.7 percent but with only 6 ratings. Pairs from other years stay between
-- 0 and 7.1 percent. Movie 15 pairs with 6 and 7 in 2008 and shows 0 ratings.
-- The pairs involving movies 2 and 3 are in different countries, except that
-- movie 3 shares Brazil with movie 5.
