-- EX 603 Unit 3, Task 3.1: Establish what the data contains
-- Database: ex603_data (loaded from movies.sql)
-- Theme: Movie / TV. Actor = users, producer = movies, event = ratings,
-- catalog = genres, junction = movie_genres.


-- 3.1 Setup check. Requirement: COUNT.
-- Question: how many rows does each table hold?
SELECT 'users' AS table_name, COUNT(*) AS row_count FROM users
UNION ALL SELECT 'movies', COUNT(*) FROM movies
UNION ALL SELECT 'genres', COUNT(*) FROM genres
UNION ALL SELECT 'movie_genres', COUNT(*) FROM movie_genres
UNION ALL SELECT 'ratings', COUNT(*) FROM ratings;
-- Result: 30 users, 15 movies, 5 genres, 25 movie_genres, 200 ratings.


-- 3.1a Available movies released after 2015, the producers whose records
-- anchor the audit. Requirement: SELECT, WHERE, ORDER BY, LIMIT.
-- Question: which movies are still available and were released after 2015?
SELECT movie_id, title, release_year
FROM movies
WHERE is_available = TRUE
AND release_year > 2015
ORDER BY release_year DESC, title
LIMIT 10;
-- Result: 7 movies came back, which is under the LIMIT of 10. Titles 1, 2, 4
-- and 5 are from 2023, titles 11 and 12 are from 2017, and title 13 is from
-- 2016. Movies 3 and 9 are excluded because they are not available.
-- The movies table in this dataset has no rating column, so I filtered on the
-- two columns the appendix names, is_available and release_year.


-- 3.1b Every status a rating can have. Requirement: SELECT DISTINCT.
-- Question: what values appear in rating_status, and are there more than
-- I expected?
SELECT DISTINCT rating_status
FROM ratings
ORDER BY rating_status;
-- Result: three values, published, withdrawn and flagged. I expected only
-- published and withdrawn, so flagged was the surprise.

-- 3.1b (follow-up) Requirement: GROUP BY, COUNT.
-- Question: how many ratings sit in each status, and what reasons do the
-- withdrawn ones carry?
SELECT rating_status, withdrawn_reason, COUNT(*) AS rating_count
FROM ratings
GROUP BY rating_status, withdrawn_reason
ORDER BY rating_status, withdrawn_reason;
-- Result: 156 published, 10 flagged, and 34 withdrawn. The withdrawn ones split
-- into 12 Spam detected, 8 Policy violation, 7 Duplicate rating and 7 User
-- request. Only withdrawn ratings have a reason, so withdrawn_reason is NULL
-- for the other 166 rows.


-- 3.1c-1 Filter on a numeric range. Requirement: BETWEEN.
-- Question: which ratings gave a score from 4.0 to 5.0?
SELECT rating_id, user_id, movie_id, score
FROM ratings
WHERE score BETWEEN 4.0 AND 5.0
ORDER BY score DESC, rating_id
LIMIT 15;
-- Result: the first 15 rows all have a score of 5.0, because the list is
-- sorted from the highest score down.

-- 3.1c-2 Filter on an explicit list of values. Requirement: IN.
-- Question: which ratings are either flagged or withdrawn?
SELECT rating_id, rating_status, withdrawn_reason
FROM ratings
WHERE rating_status IN ('flagged', 'withdrawn')
ORDER BY rating_id
LIMIT 15;
-- Result: both queries return rows, and the IN query matches 44 rows in total
-- (10 flagged and 34 withdrawn). I limited the display to 15.


-- 3.1d-1 Match a text pattern. Requirement: LIKE.
-- Question: which movies have a title that starts with Title_1?
-- In LIKE an underscore is a wildcard for any single character, so I
-- escaped it with a backslash to match a literal underscore.
SELECT movie_id, title
FROM movies
WHERE title LIKE 'Title\_1%'
ORDER BY movie_id;
-- Result: movies 10 through 15.

-- 3.1d-2 Find missing values. Requirement: IS NULL, COALESCE.
-- Question: which ratings have no withdrawn reason, shown with a label
-- a reader can understand instead of a blank?
SELECT rating_id, rating_status,
    COALESCE(withdrawn_reason, 'No reason provided') AS reason_shown
FROM ratings
WHERE withdrawn_reason IS NULL
ORDER BY rating_id
LIMIT 15;
-- Result: all 166 published and flagged ratings have a NULL reason. That is
-- expected for published ratings, but the 10 flagged ones also show
-- No reason provided, which is worth knowing because they are not withdrawn yet.


-- 3.1e Calculated columns in plain language. Requirement: CASE, arithmetic,
-- EXTRACT. Question: for each rating, how would I describe the score, how
-- much does it count once its weight is applied, and what time of day
-- was it left?
SELECT rating_id, score,
    CASE
        WHEN score >= 4.5 THEN 'Loved it'
        WHEN score >= 3.5 THEN 'Liked it'
        WHEN score >= 2.0 THEN 'Mixed'
        ELSE 'Disliked it'
    END AS score_label,
    ROUND(score * weight, 2) AS weighted_score,
    CASE
        WHEN EXTRACT(HOUR FROM rated_at) BETWEEN 5 AND 11 THEN 'Morning'
        WHEN EXTRACT(HOUR FROM rated_at) BETWEEN 12 AND 16 THEN 'Afternoon'
        WHEN EXTRACT(HOUR FROM rated_at) BETWEEN 17 AND 21 THEN 'Evening'
        ELSE 'Late night'
    END AS time_of_day
FROM ratings
ORDER BY rating_id
LIMIT 15;
-- Result: each row now has a label, a weighted score and a time of day that
-- someone outside the data team could read without knowing the column names.
