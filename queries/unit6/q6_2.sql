-- EX 603 Unit 6, Task 6.2: Compare each row to its neighbors
-- Database: ex603_data (loaded from movies.sql)
-- Question: is a movie's score going up or down from one rating to the next,
-- how is the platform doing over time in total and on a recent average, and
-- where does a movie stop receiving ratings for a while?
-- Producers are movies, events are ratings, and the metric is ratings.score.
-- The failure state is a spam withdrawal, a rating whose withdrawn_reason is
-- Spam detected.


-- Part A: Row to row

-- 6.2A-1 Requirement: LAG() and LEAD() partitioned by producer and ordered by
-- timestamp, a delta column, and the output filtered to one producer.
-- Question: for movie 2, what score came before and after each rating, and
-- how much did the score change from the previous rating?
-- The window runs over every movie in the CTE, and the filter to movie 2 is
-- in the outer query. A WHERE inside the CTE would run before the window and
-- would also work for one movie, but keeping the window on the full table is
-- the safer habit. rating_id breaks ties in rated_at so the order is fixed.
-- The first rating has no previous rating, so its delta is NULL, which means
-- there is nothing to compare with, not a change of zero.
WITH neighbours AS (
    SELECT
        movie_id,
        rating_id,
        rated_at,
        rating_status,
        score,
        LAG(score)  OVER (PARTITION BY movie_id ORDER BY rated_at, rating_id) AS prev_score,
        LEAD(score) OVER (PARTITION BY movie_id ORDER BY rated_at, rating_id) AS next_score,
        score - LAG(score) OVER (PARTITION BY movie_id ORDER BY rated_at, rating_id) AS delta
    FROM ratings
)
SELECT rating_id, rated_at, rating_status, score, prev_score, next_score, delta
FROM neighbours
WHERE movie_id = 2
ORDER BY rated_at, rating_id;
-- Result: 16 rows. The largest changes are -2.9 (ratings 15 to 26, on 17
-- December), +2.8 (ratings 21 to 13, on 12 April) and +2.7 (ratings 25 to
-- 17, on 11 August). Two of those three involve a withdrawn rating, which
-- always has a score of 0.5. Movie 2 has four withdrawn ratings, and three
-- of them fall in the first ten weeks of the year.
-- Between 12 April and 11 August, when every rating was published, the score
-- moved up and down between 2.2 and 5.0 with no clear direction.

-- 6.2A-2 Requirement: follow-up on large deltas across every movie.
-- Question: how many rating-to-rating changes are 2.5 points or more, and
-- how many of them involve a withdrawn rating on either side?
-- 2.5 points is half of the 5-point scale.
WITH neighbours AS (
    SELECT
        rating_status,
        LAG(rating_status) OVER (PARTITION BY movie_id ORDER BY rated_at, rating_id) AS prev_status,
        score - LAG(score) OVER (PARTITION BY movie_id ORDER BY rated_at, rating_id) AS delta
    FROM ratings
)
SELECT
    COUNT(delta) AS all_deltas,
    COUNT(*) FILTER (WHERE ABS(delta) >= 2.5) AS large_deltas,
    COUNT(*) FILTER (WHERE ABS(delta) >= 2.5
                       AND (rating_status = 'withdrawn' OR prev_status = 'withdrawn'))
        AS large_with_withdrawn,
    COUNT(*) FILTER (WHERE ABS(delta) >= 2.5
                       AND rating_status <> 'withdrawn' AND prev_status <> 'withdrawn')
        AS large_without_withdrawn
FROM neighbours;
-- Result: 187 deltas (200 ratings minus the first rating of each of the 13
-- movies). 67 of them are 2.5 points or more. 28 of those involve a
-- withdrawn rating, and 39 are between two ratings that were not withdrawn.
-- So a large delta is often the 0.5 placeholder, but more than half are real
-- scores that disagree.


-- Part B: Cumulative and smoothed

-- 6.2B-1 Requirement: SUM(...) OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED
-- PRECEDING AND CURRENT ROW) for a running total, measured against a target.
-- Question: day by day, how many ratings has the platform collected so far
-- in 2023, and how close is that to the target?
-- Target: 240 ratings for 2023, which is 20 a month. I set it about 20
-- percent above the 2023 monthly average of 16.7, as a growth goal for a
-- platform whose ratings feed rankings. on_pace_target is where the running
-- total should be on that day if ratings arrived evenly through the year.
-- Only days with at least one rating have a row (155 of the 362 days from
-- 1 January to 28 December), which does not affect a running total.
WITH daily AS (
    SELECT rated_at::date AS rating_day, COUNT(*) AS daily_ratings
    FROM ratings
    GROUP BY rated_at::date
)
SELECT
    rating_day,
    daily_ratings,
    SUM(daily_ratings) OVER (ORDER BY rating_day
                             ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS running_total,
    ROUND(240.0 * EXTRACT(DOY FROM rating_day) / 365) AS on_pace_target,
    ROUND(100.0 * SUM(daily_ratings) OVER (ORDER BY rating_day
                                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
          / 240, 1) AS pct_of_year_target
FROM daily
ORDER BY rating_day;
-- Result: 155 rows, one per day with ratings. The running total ends at 200
-- on 28 December, which is 83.3 percent of the 240 target. The on-pace
-- target for that day is 238, so the platform finished the year 38 ratings
-- short.

-- 6.2B-2 Requirement: the running total at the end of each month.
-- Question: where did the running total stand at the end of each month,
-- against the target pace of 20 a month?
-- The window runs in the CTE over every day. The outer query keeps only the
-- last day with ratings in each month, so the totals are not recomputed.
WITH daily AS (
    SELECT rated_at::date AS rating_day, COUNT(*) AS daily_ratings
    FROM ratings
    GROUP BY rated_at::date
),
running AS (
    SELECT
        rating_day,
        SUM(daily_ratings) OVER (ORDER BY rating_day
                                 ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
            AS running_total,
        ROW_NUMBER() OVER (PARTITION BY DATE_TRUNC('month', rating_day)
                           ORDER BY rating_day DESC) AS rn_in_month
    FROM daily
)
SELECT
    TO_CHAR(rating_day, 'YYYY-MM') AS month,
    running_total,
    20 * EXTRACT(MONTH FROM rating_day)::int AS target_by_month_end,
    running_total - 20 * EXTRACT(MONTH FROM rating_day)::int AS behind_or_ahead,
    ROUND(100.0 * running_total / 240, 1) AS pct_of_year_target
FROM running
WHERE rn_in_month = 1
ORDER BY rating_day;
-- Result: 12 rows. The platform was ahead of the target after January (21)
-- and February (42). It fell behind in March and April, when only 11
-- ratings arrived each month, and ended April 16 short. It never caught up.
-- The shortfall grew slowly after that, to 40 by the end of December,
-- because most months after April landed at 14 to 18 ratings, under the 20
-- a month the target needs.

-- 6.2B-3 Requirement: AVG(...) OVER (... ROWS BETWEEN n PRECEDING AND CURRENT
-- ROW) for a moving average.
-- Question: what share of the most recent ratings were spam withdrawals, at
-- each point in the year?
-- is_spam is 1 for a spam withdrawal and 0 for every other rating, so the
-- average of is_spam over a window is the spam rate of that window. ROWS
-- counts ratings here, not days, which is the unit I want: the last 30
-- ratings, however many days they span. The 10-rating column is there to
-- show what a smaller window does. The first 29 rows have fewer than 30
-- ratings behind them, so their window is shorter, and window_size shows it.
WITH flagged AS (
    SELECT
        rating_id,
        rated_at,
        CASE WHEN withdrawn_reason = 'Spam detected' THEN 1 ELSE 0 END AS is_spam
    FROM ratings
)
SELECT
    rating_id,
    rated_at,
    is_spam,
    COUNT(*) OVER (ORDER BY rated_at, rating_id
                   ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS window_size,
    ROUND(100.0 * AVG(is_spam) OVER (ORDER BY rated_at, rating_id
                                     ROWS BETWEEN 29 PRECEDING AND CURRENT ROW), 1)
        AS spam_pct_last_30,
    ROUND(100.0 * AVG(is_spam) OVER (ORDER BY rated_at, rating_id
                                     ROWS BETWEEN 9 PRECEDING AND CURRENT ROW), 1)
        AS spam_pct_last_10
FROM flagged
ORDER BY rated_at, rating_id;
-- Result: 200 rows. The first rows look alarming because the window is
-- small. The very first rating is a spam withdrawal, so both columns start
-- at 100.0. Once the 30-rating window is full, it stays between 0.0 and
-- 10.0. It reaches 10.0 only between 3 May and 20 September, sits at 0.0
-- for 22 ratings in a row from 17 October to 13 December, and ends the year
-- at 6.7 (2 of the last 30 ratings, both in December). The 10-rating column jumps between 0.0, 10.0 and 20.0
-- every time a single spam rating enters or leaves the window.

-- 6.2B-4 Requirement: compare window sizes.
-- Question: how far does each moving average swing once its window is full?
-- Rows are numbered first, so the comparison only uses rows where the window
-- holds its full 10 or 30 ratings.
WITH flagged AS (
    SELECT
        rated_at,
        rating_id,
        CASE WHEN withdrawn_reason = 'Spam detected' THEN 1 ELSE 0 END AS is_spam
    FROM ratings
),
rolling AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY rated_at, rating_id) AS n,
        AVG(is_spam) OVER (ORDER BY rated_at, rating_id
                           ROWS BETWEEN 9 PRECEDING AND CURRENT ROW)  AS rate_10,
        AVG(is_spam) OVER (ORDER BY rated_at, rating_id
                           ROWS BETWEEN 29 PRECEDING AND CURRENT ROW) AS rate_30
    FROM flagged
)
SELECT
    '10 ratings' AS window_length,
    ROUND(100 * MIN(rate_10), 1) AS lowest_pct,
    ROUND(100 * MAX(rate_10), 1) AS highest_pct,
    COUNT(DISTINCT rate_10) AS distinct_values
FROM rolling WHERE n >= 10
UNION ALL
SELECT
    '30 ratings',
    ROUND(100 * MIN(rate_30), 1),
    ROUND(100 * MAX(rate_30), 1),
    COUNT(DISTINCT rate_30)
FROM rolling WHERE n >= 30;
-- Result: the 10-rating window swings from 0.0 to 20.0 percent and only ever
-- takes 3 values (0, 10 and 20), so one rating moves it by 10 points. The
-- 30-rating window swings from 0.0 to 10.0 percent across 4 values, so one
-- rating moves it by 3.3 points.

-- 6.2B-5 Requirement: ROWS compared with RANGE when rows share an ORDER BY
-- value.
-- Question: when two ratings fall on the same day, how do a ROWS running
-- count and a RANGE running count differ?
-- No two ratings share an exact rated_at, so ordering by the timestamp would
-- show no difference. Ordering by the day gives ties, because 42 days have
-- two or three ratings. ROWS adds one rating at a time, so ratings on the
-- same day get different counts. RANGE, the default frame when ORDER BY is
-- given, treats every rating on the same day as the current row, so they all
-- get the day's full count. The first 15 rows are enough to show it.
SELECT
    rated_at::date AS rating_day,
    rating_id,
    COUNT(*) OVER (ORDER BY rated_at::date, rating_id
                   ROWS  BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_rows,
    COUNT(*) OVER (ORDER BY rated_at::date
                   RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_range
FROM ratings
ORDER BY rated_at::date, rating_id
LIMIT 15;
-- Result: the two columns agree on days with one rating and disagree on days
-- with more. On 8 January, ratings 56, 169 and 190 get 4, 5 and 6 with ROWS
-- and 6, 6 and 6 with RANGE. On 10, 20 and 23 January the first rating of
-- the day shows the day's total under RANGE before the second rating has
-- been counted under ROWS.


-- Part C: Where the series stops

-- 6.2C-1 Requirement: LAG() comparing adjacent rows, a CTE that computes the
-- gap, and a WHERE in the outer query that keeps only the gaps.
-- Question: which movies went unusually long without a rating and then
-- started again?
-- A window result cannot be filtered with WHERE or HAVING in the same query,
-- because the window function runs after both. The gap is computed in the
-- CTE and filtered in the outer query.
-- "Unusually long" is measured against each movie's own pace. typical_gap is
-- the time from the movie's first to last rating divided by the number of
-- gaps between them. A gap at least 4 times longer than that is kept. A
-- fixed number of days would treat a busy movie and a quiet one the same.
WITH spaced AS (
    SELECT
        movie_id,
        rated_at,
        LAG(rated_at) OVER (PARTITION BY movie_id ORDER BY rated_at, rating_id) AS prev_rated_at,
        (MAX(rated_at) OVER (PARTITION BY movie_id) - MIN(rated_at) OVER (PARTITION BY movie_id))
            / (COUNT(*) OVER (PARTITION BY movie_id) - 1) AS typical_gap
    FROM ratings
),
gaps AS (
    SELECT
        movie_id,
        prev_rated_at,
        rated_at,
        rated_at - prev_rated_at AS gap,
        typical_gap,
        EXTRACT(EPOCH FROM rated_at - prev_rated_at) / EXTRACT(EPOCH FROM typical_gap) AS times_typical
    FROM spaced
    WHERE prev_rated_at IS NOT NULL
)
SELECT
    movie_id,
    prev_rated_at::date AS last_rating_before,
    rated_at::date      AS first_rating_after,
    EXTRACT(DAY FROM gap)::int         AS gap_days,
    EXTRACT(DAY FROM typical_gap)::int AS typical_gap_days,
    ROUND(times_typical::numeric, 1)   AS times_typical
FROM gaps
WHERE times_typical >= 4
ORDER BY times_typical DESC;
-- Result: 4 gaps. Movie 12 went 106 days without a rating (2 March to 17
-- June, 4.8 times its usual spacing), movie 5 went 93 days (1 February to 5
-- May), movie 11 went 89 days (7 March to 4 June) and movie 9 went 112 days
-- (5 January to 28 April). Movie 9's gap is the longest in days, and it
-- starts right after the movie's first rating of the year. The next gap
-- below the line is movie 2 at 3.9 times typical (11 August to 5 November).
-- All four gaps cover 8 March to 27 April.

-- 6.2C-2 Requirement: context for each gap.
-- Question: while each of these movies had no ratings, was the rest of the
-- platform still recording ratings, and is the movie available today?
-- If the platform had stopped recording, other movies would show no ratings
-- in the same window. The same gap logic as 6.2C-1 is repeated so this query
-- runs on its own.
WITH spaced AS (
    SELECT
        movie_id,
        rated_at,
        LAG(rated_at) OVER (PARTITION BY movie_id ORDER BY rated_at, rating_id) AS prev_rated_at,
        (MAX(rated_at) OVER (PARTITION BY movie_id) - MIN(rated_at) OVER (PARTITION BY movie_id))
            / (COUNT(*) OVER (PARTITION BY movie_id) - 1) AS typical_gap
    FROM ratings
),
gaps AS (
    SELECT movie_id, prev_rated_at, rated_at
    FROM spaced
    WHERE prev_rated_at IS NOT NULL
      AND EXTRACT(EPOCH FROM rated_at - prev_rated_at) / EXTRACT(EPOCH FROM typical_gap) >= 4
)
SELECT
    g.movie_id,
    g.prev_rated_at::date AS gap_start,
    g.rated_at::date      AS gap_end,
    m.is_available,
    COUNT(o.rating_id)            AS other_ratings_in_gap,
    COUNT(DISTINCT o.movie_id)    AS other_movies_rated_in_gap
FROM gaps g
INNER JOIN movies m ON m.movie_id = g.movie_id
LEFT JOIN ratings o
       ON o.movie_id <> g.movie_id
      AND o.rated_at > g.prev_rated_at
      AND o.rated_at < g.rated_at
GROUP BY g.movie_id, g.prev_rated_at, g.rated_at, m.is_available
ORDER BY g.prev_rated_at;
-- Result: 4 rows. During every gap, 11 or 12 other movies were still being
-- rated, from 40 ratings (movie 11's gap) to 61 (movie 9's gap). So the
-- platform kept recording ratings while each of these movies was quiet.
-- Movie 9 is the only one of the four marked unavailable today. In the
-- window all four gaps share (8 March to 27 April) the whole platform
-- recorded only 18 ratings on 7 movies, which is the March and April dip in
-- 6.2B-2.
