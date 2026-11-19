-- EX 603 Unit 6, Task 6.3: Build the reporting patterns
-- Database: ex603_data (loaded from movies.sql)
-- Question: what are the three best ratings for each movie, and is the
-- platform getting better or worse from one month to the next?
-- Producers are movies, events are ratings, and the metric is ratings.score.
-- The failure state is a spam withdrawal, a rating whose withdrawn_reason is
-- Spam detected.


-- Part A: Top N per category

-- 6.3A-1 Requirement: a ranking window function partitioned by producer, a
-- CTE that filters to rank <= 3, and FIRST_VALUE().
-- Question: for each movie, which three published ratings have the highest
-- scores, and what is the movie's best score?
-- Only published ratings are ranked. Withdrawn ratings all carry the 0.5
-- placeholder, and flagged ratings are still under review, so neither should
-- appear in a list of top reviews.
-- Ties at third place: ROW_NUMBER is used, with the newest rating first when
-- scores tie. The feature this feeds has exactly three slots, so it needs
-- exactly three rows per movie, and a newer review is more useful to a
-- viewer than an older one with the same score. RANK would keep every tied
-- rating, which returns 4 to 6 rows for five of the movies (see 6.3A-2).
-- FIRST_VALUE returns the score of the first row in the window, which is the
-- best score because the window is ordered by score descending. FIRST_VALUE
-- is safe with the default frame, since the frame always starts at the first
-- row of the partition. LAST_VALUE would need ROWS BETWEEN UNBOUNDED
-- PRECEDING AND UNBOUNDED FOLLOWING to see past the current row.
WITH ranked AS (
    SELECT
        movie_id,
        rating_id,
        rated_at,
        score,
        ROW_NUMBER() OVER (PARTITION BY movie_id
                           ORDER BY score DESC, rated_at DESC) AS review_rank,
        FIRST_VALUE(score) OVER (PARTITION BY movie_id
                                 ORDER BY score DESC, rated_at DESC) AS best_score,
        COUNT(*) OVER (PARTITION BY movie_id) AS published_ratings
    FROM ratings
    WHERE rating_status = 'published'
)
SELECT movie_id, review_rank, rating_id, rated_at, score, best_score, published_ratings
FROM ranked
WHERE review_rank <= 3
ORDER BY movie_id, review_rank;
-- Result: 39 rows, exactly 3 for each of the 13 movies with ratings. Every
-- movie has at least 4 published ratings (movie 4 has the fewest), so each
-- one fills all three slots. Twelve of the 13 movies have a best published
-- score of 5.0. Movie 1 is the only exception, at 4.8. For movies 5, 6, 7, 8 and 10
-- all three slots are 5.0, so the newest-first tiebreaker decides which
-- 5.0 ratings are shown.

-- 6.3A-2 Requirement: show how ties at third place are handled.
-- Question: for which movies is the third-best score tied with the fourth,
-- and how many rows would RANK() <= 3 return for each movie instead of 3?
WITH ranked AS (
    SELECT
        movie_id,
        score,
        ROW_NUMBER() OVER (PARTITION BY movie_id
                           ORDER BY score DESC, rated_at DESC) AS rn,
        RANK()       OVER (PARTITION BY movie_id ORDER BY score DESC) AS rk
    FROM ratings
    WHERE rating_status = 'published'
)
SELECT
    movie_id,
    MAX(score) FILTER (WHERE rn = 3) AS third_score,
    MAX(score) FILTER (WHERE rn = 4) AS fourth_score,
    COUNT(*)   FILTER (WHERE rn <= 3) AS row_number_rows,
    COUNT(*)   FILTER (WHERE rk <= 3) AS rank_rows
FROM ranked
GROUP BY movie_id
HAVING MAX(score) FILTER (WHERE rn = 3) = MAX(score) FILTER (WHERE rn = 4)
ORDER BY movie_id;
-- Result: 5 movies have a tie at third place. Movies 5, 7, 8 and 10 tie at
-- 5.0 and movie 12 ties at 4.5. ROW_NUMBER returns 3 rows for each of them,
-- while RANK() <= 3 would return 6 (movie 5), 4 (movie 7), 5 (movie 8),
-- 6 (movie 10) and 4 (movie 12).


-- Part B: Period over period

-- 6.3B-1 Requirement: check for missing months before using LAG.
-- Question: does every calendar month from the first rating to the last have
-- at least one rating?
-- generate_series builds the full list of months, and the LEFT JOIN keeps
-- every month whether or not it has ratings. LAG counts rows, not months, so
-- a missing month would make it compare two months that are not next to
-- each other.
WITH bounds AS (
    SELECT DATE_TRUNC('month', MIN(rated_at)) AS first_month,
           DATE_TRUNC('month', MAX(rated_at)) AS last_month
    FROM ratings
),
calendar AS (
    SELECT generate_series(first_month, last_month, INTERVAL '1 month') AS month_start
    FROM bounds
),
actual AS (
    SELECT DATE_TRUNC('month', rated_at) AS month_start, COUNT(*) AS ratings
    FROM ratings
    GROUP BY DATE_TRUNC('month', rated_at)
)
SELECT
    (SELECT COUNT(*) FROM calendar) AS months_expected,
    COUNT(a.month_start)            AS months_with_ratings,
    COUNT(*) FILTER (WHERE a.month_start IS NULL) AS months_missing
FROM calendar c
LEFT JOIN actual a ON a.month_start = c.month_start;
-- Result: 12 months expected (January to December 2023), 12 have ratings,
-- and 0 are missing. LAG will compare each month with the one before it.

-- 6.3B-2 Requirement: group by calendar month, LAG() over the monthly series,
-- a percent change that avoids division by zero, and a guard against
-- missing months.
-- Question: month by month, is the platform getting more or fewer ratings,
-- and is the spam rate going up or down?
-- Percent change uses NULLIF(previous, 0), so a month that follows a month
-- with zero spam shows NULL. NULL there means the change cannot be expressed
-- as a percent, not that nothing changed. The spam rate change is also given
-- in percentage points, which is defined even when the previous rate is 0.
-- prev_is_previous_month checks that the row LAG reached is really the
-- calendar month before. It is true on every row here, which matches 6.3B-1.
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', rated_at)::date AS month_start,
        COUNT(*) AS ratings,
        COUNT(*) FILTER (WHERE withdrawn_reason = 'Spam detected') AS spam,
        ROUND(100.0 * COUNT(*) FILTER (WHERE withdrawn_reason = 'Spam detected')
              / COUNT(*), 1) AS spam_rate_pct
    FROM ratings
    GROUP BY DATE_TRUNC('month', rated_at)
),
compared AS (
    SELECT
        month_start,
        ratings,
        spam,
        spam_rate_pct,
        LAG(month_start)   OVER (ORDER BY month_start) AS prev_month,
        LAG(ratings)       OVER (ORDER BY month_start) AS prev_ratings,
        LAG(spam)          OVER (ORDER BY month_start) AS prev_spam,
        LAG(spam_rate_pct) OVER (ORDER BY month_start) AS prev_spam_rate_pct
    FROM monthly
)
SELECT
    TO_CHAR(month_start, 'YYYY-MM') AS month,
    ratings,
    ROUND(100.0 * (ratings - prev_ratings) / NULLIF(prev_ratings, 0), 1) AS ratings_pct_change,
    spam,
    ROUND(100.0 * (spam - prev_spam) / NULLIF(prev_spam, 0), 1) AS spam_pct_change,
    spam_rate_pct,
    spam_rate_pct - prev_spam_rate_pct AS spam_rate_change_pts,
    prev_month = (month_start - INTERVAL '1 month')::date AS prev_is_previous_month
FROM compared
ORDER BY month_start;
-- Result: 12 rows. Volume fell 47.6 percent from February (21) to March
-- (11), stayed at 11 in April, and jumped 54.5 percent to 17 in May. After
-- that it moved between 14 and 20 a month. The spam rate swings far more
-- than volume, because one spam withdrawal in a month of 11 to 21 ratings is
-- worth 5 to 9 points. March reached 18.2 percent on 2 spam withdrawals and
-- April fell to 0. spam_pct_change is NULL in March, May, November and
-- December, because the month before had 0 spam. prev_is_previous_month is
-- true on every row after January, so no comparison skips a month.

-- 6.3B-3 Requirement: the same comparison by quarter.
-- Question: with only 0 to 2 spam withdrawals a month, does the trend look
-- clearer by quarter?
WITH quarterly AS (
    SELECT
        DATE_TRUNC('quarter', rated_at)::date AS quarter_start,
        COUNT(*) AS ratings,
        COUNT(*) FILTER (WHERE withdrawn_reason = 'Spam detected') AS spam,
        ROUND(100.0 * COUNT(*) FILTER (WHERE withdrawn_reason = 'Spam detected')
              / COUNT(*), 1) AS spam_rate_pct
    FROM ratings
    GROUP BY DATE_TRUNC('quarter', rated_at)
)
SELECT
    EXTRACT(YEAR FROM quarter_start) || '-Q' || EXTRACT(QUARTER FROM quarter_start) AS quarter,
    ratings,
    spam,
    spam_rate_pct,
    spam_rate_pct - LAG(spam_rate_pct) OVER (ORDER BY quarter_start) AS spam_rate_change_pts,
    ROUND(100.0 * (ratings - LAG(ratings) OVER (ORDER BY quarter_start))
          / NULLIF(LAG(ratings) OVER (ORDER BY quarter_start), 0), 1) AS ratings_pct_change
FROM quarterly
ORDER BY quarter_start;
-- Result: 4 rows. The spam rate fell every quarter, from 7.5 percent (4 of
-- 53) to 6.3 (3 of 48), 5.9 (3 of 51) and 4.2 (2 of 48). Volume stayed
-- between 48 and 53 a quarter. The direction is consistent, but the counts
-- are small. One more spam withdrawal in the fourth quarter would have put
-- it at 6.3 percent, level with the second quarter.
