-- EX 603 Unit 3, Task 3.3: Hand the team a corrected query
-- Database: ex603_data (loaded from movies.sql)
-- Two-step question: which users left at least one spam-withdrawn rating?
-- Step one finds the spam withdrawals in ratings. Step two finds the users who
-- wrote them.
-- Result for all three forms: 10 users, ids 1, 4, 6, 7, 15, 17, 19, 21, 27, 29.

-- 3.3a Form one: a subquery with IN. Requirement: IN subquery.
-- Question: which users appear in the list of users who wrote a spam withdrawal?
SELECT user_id, user_name
FROM users
WHERE user_id IN (
    SELECT user_id
    FROM ratings
    WHERE rating_status = 'withdrawn'
    AND withdrawn_reason = 'Spam detected'
)
ORDER BY user_id;

-- 3.3b Form two: a Common Table Expression. Requirement: WITH.
-- Question: which users match the spam withdrawers I first collect in a
-- named step, so each user is listed once?
WITH spam_ratings AS (
    SELECT DISTINCT user_id
    FROM ratings
    WHERE rating_status = 'withdrawn'
    AND withdrawn_reason = 'Spam detected'
)
SELECT u.user_id, u.user_name
FROM users u
JOIN spam_ratings s ON s.user_id = u.user_id
ORDER BY u.user_id;

-- 3.3c Form three: a correlated EXISTS subquery. Requirement: a different
-- subquery form from the first two.
-- Question: for each user, does at least one spam withdrawal of theirs exist?
SELECT u.user_id, u.user_name
FROM users u
WHERE EXISTS (
    SELECT 1
    FROM ratings r
    WHERE r.user_id = u.user_id
    AND r.rating_status = 'withdrawn'
    AND r.withdrawn_reason = 'Spam detected'
)
ORDER BY u.user_id;

-- 3.3d Proof that the rows match, not just the counts.
-- Requirement: identical result sets, shown with the rows themselves.
-- Question: do the three forms return the same rows? The first three lines
-- list the ids each form returned so they can be compared by eye. The last
-- four count rows that appear in one form but not another, and all four
-- numbers should be zero.
WITH f1 AS (
    SELECT user_id FROM users
    WHERE user_id IN (
        SELECT user_id FROM ratings
        WHERE rating_status = 'withdrawn'
        AND withdrawn_reason = 'Spam detected'
    )
),
f2 AS (
    SELECT u.user_id
    FROM users u
    JOIN (
        SELECT DISTINCT user_id FROM ratings
        WHERE rating_status = 'withdrawn'
        AND withdrawn_reason = 'Spam detected'
    ) s ON s.user_id = u.user_id
),
f3 AS (
    SELECT u.user_id FROM users u
    WHERE EXISTS (
        SELECT 1 FROM ratings r
        WHERE r.user_id = u.user_id
        AND r.rating_status = 'withdrawn'
        AND r.withdrawn_reason = 'Spam detected'
    )
)
SELECT 'form 1 (IN)' AS form, COUNT(*) AS row_count,
    string_agg(user_id::text, ',' ORDER BY user_id) AS user_ids FROM f1
UNION ALL
SELECT 'form 2 (WITH)', COUNT(*),
    string_agg(user_id::text, ',' ORDER BY user_id) FROM f2
UNION ALL
SELECT 'form 3 (EXISTS)', COUNT(*),
    string_agg(user_id::text, ',' ORDER BY user_id) FROM f3
UNION ALL
SELECT 'in 1 not in 2', COUNT(*), NULL FROM (SELECT * FROM f1 EXCEPT SELECT * FROM f2) x
UNION ALL
SELECT 'in 2 not in 1', COUNT(*), NULL FROM (SELECT * FROM f2 EXCEPT SELECT * FROM f1) x
UNION ALL
SELECT 'in 1 not in 3', COUNT(*), NULL FROM (SELECT * FROM f1 EXCEPT SELECT * FROM f3) x
UNION ALL
SELECT 'in 3 not in 1', COUNT(*), NULL FROM (SELECT * FROM f3 EXCEPT SELECT * FROM f1) x;


-- Condition where the forms stop being equivalent: NULLs under NOT IN.
-- Requirement: name one input condition under which the forms differ.
-- The three forms above agree because IN and EXISTS both ignore NULLs. If the
-- question were flipped to NOT IN, one NULL in the list would make every
-- comparison UNKNOWN. I show it on a question where this really happens.
-- Question: which users have never invited anyone? invited_by is nullable, and
-- one NULL inside a NOT IN list makes every comparison UNKNOWN.

-- 3.3e NOT IN with a NULL in the list. Returns no rows.
SELECT COUNT(*) AS users_never_inviting_not_in
FROM users
WHERE user_id NOT IN (SELECT invited_by FROM users);

-- 3.3f NOT EXISTS on the same question. Returns the real answer.
SELECT COUNT(*) AS users_never_inviting_not_exists
FROM users u
WHERE NOT EXISTS (SELECT 1 FROM users i WHERE i.invited_by = u.user_id);
-- Result: NOT IN returns 0 and NOT EXISTS returns 17. Several users have a NULL
-- invited_by, so the NOT IN list contains a NULL and no row can ever be TRUE.
-- The same thing would happen to a NOT IN version of the spam question if
-- ratings.user_id were nullable. It is NOT NULL in this dataset, so the three
-- forms above agree.
-- Duplicates are a second place equivalence breaks. A plain JOIN to ratings
-- without DISTINCT would list a user once per spam rating, and the CTE form
-- uses DISTINCT for that reason.
