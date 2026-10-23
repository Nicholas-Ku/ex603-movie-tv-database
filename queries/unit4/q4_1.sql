-- EX 603 Unit 4, Task 4.1: Measure the platform
-- Database: ex603_data (loaded from movies.sql)
-- Theme: Movie / TV. Actor = users, producer = movies, event = ratings.
-- Metric: ratings.score. Failure state: a spam withdrawal, meaning a rating
-- whose rating_status is withdrawn and whose withdrawn_reason is Spam detected.
-- Producers are reported by movie_id, not by title.


-- 4.1a Platform baseline. Requirement: COUNT, SUM, AVG, MIN, MAX, COUNT(DISTINCT).
-- Question: across every rating, what are the count, total, average, lowest
-- and highest score, and how many distinct users and movies appear?
SELECT
    COUNT(*)                  AS rating_count,
    SUM(score)                AS total_score,
    ROUND(AVG(score), 2)      AS avg_score,
    MIN(score)                AS min_score,
    MAX(score)                AS max_score,
    COUNT(DISTINCT user_id)   AS distinct_users,
    COUNT(DISTINCT movie_id)  AS distinct_movies_rated
FROM ratings;
-- Result: 200 ratings, a total score of 569.3, an average of 2.85, a minimum
-- of 0.5, a maximum of 5.0, 30 distinct users, and 13 distinct movies. The
-- movies table holds 15 movies, so two of them have never been rated and
-- cannot appear in any grouped result below.

-- 4.1a (follow-up) Requirement: GROUP BY, conditional counts, AVG.
-- Question: the minimum is not zero, but 0.5 is still suspicious. Which
-- ratings sit exactly at the lowest and highest score, and does the average
-- change if I split it by status?
SELECT
    rating_status,
    COUNT(*)                                    AS rating_count,
    COUNT(CASE WHEN score = 0.5 THEN 1 END)     AS at_minimum,
    COUNT(CASE WHEN score = 5.0 THEN 1 END)     AS at_maximum,
    ROUND(AVG(score), 2)                        AS avg_score
FROM ratings
GROUP BY rating_status
ORDER BY rating_status;
-- Result: all 34 withdrawn ratings have a score of exactly 0.5, and no
-- published or flagged rating does. Published ratings average 3.32 and the
-- withdrawn ones average 0.5, which is what pulls the platform average down to
-- 2.85. A score of 0.5 on every withdrawn rating looks like a placeholder, but
-- I can't tell from this table whether users actually gave that score. Either
-- way, the average over all 200 ratings does not measure how people rate
-- movies.


-- 4.1b Activity and performance per producer. Requirement: GROUP BY, COUNT, AVG, ORDER BY.
-- Question: how many ratings does each movie have and what is its average
-- score, from the most rated movie to the least rated?
-- movie_id is the second sort key so that movies with equal counts always
-- come back in the same order.
SELECT
    movie_id,
    COUNT(*)              AS rating_count,
    ROUND(AVG(score), 2)  AS avg_score
FROM ratings
GROUP BY movie_id
ORDER BY rating_count DESC, movie_id;
-- Result: 13 rows. Movie 6 has the most ratings (21), then 8 (20) and 10 (19).
-- Movie 4 has the fewest with only 6, and the next smallest are movies 1 and
-- 13 with 11 each. Average scores run from 2.09 (movie 11) to 3.51 (movie 5).


-- 4.1c Producers with enough volume. Requirement: HAVING.
-- Question: which movies have at least 10 ratings, so that a rate computed
-- for them means something?
-- I chose a threshold of 10 because the platform has 200 ratings over 13
-- movies, so a typical movie has about 15. Below 10, one rating moves a rate
-- by 10 percentage points or more, and a single spam withdrawal on 6 ratings
-- would read as a 17 percent failure rate. At 10 I keep 12 of the 13 movies,
-- so the filter drops only the movie with too little data.
SELECT
    movie_id,
    COUNT(*)              AS rating_count,
    ROUND(AVG(score), 2)  AS avg_score
FROM ratings
GROUP BY movie_id
HAVING COUNT(*) >= 10
ORDER BY rating_count DESC, movie_id;
-- Result: 12 movies pass. Only movie 4 is dropped, because it has 6 ratings.

-- 4.1c (follow-up) Requirement: HAVING.
-- Question: which movies did the threshold exclude?
SELECT movie_id, COUNT(*) AS rating_count
FROM ratings
GROUP BY movie_id
HAVING COUNT(*) < 10
ORDER BY movie_id;
-- Result: movie 4 with 6 ratings.


-- 4.1d Two dimensions at once. Requirement: GROUP BY two columns.
-- Question: for each region and each rating status, how many ratings are
-- there and what do their scores look like?
-- The dataset has no column called region. I used ratings.device_country,
-- the country the rating was submitted from, because it sits on the event
-- table and has the same five values for every rating.
SELECT
    device_country        AS region,
    rating_status,
    COUNT(*)              AS rating_count,
    ROUND(AVG(score), 2)  AS avg_score,
    MIN(score)            AS min_score,
    MAX(score)            AS max_score
FROM ratings
GROUP BY device_country, rating_status
ORDER BY region, rating_status;
-- Result: 14 rows, one for each region and status combination that exists.
-- It is 14 and not 15 because India has no flagged ratings, and a combination
-- with no rows does not appear at all. Every withdrawn row has an average,
-- minimum and maximum of 0.5, so the 0.5 pattern from 4.1a shows up in every
-- region. Published ratings average between 2.86 (Vietnam) and 3.54
-- (India). India also has the most withdrawn ratings, 11 of its 40.
