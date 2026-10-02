# Unit 1 Analysis

## Modelling justification

I used a generated bigint primary key for users, movies, ratings, and genres. Names and titles are not unique in the real world. Two users can share a display name, and two different movies can share a title, so none of them can promise to identify a row for the life of the platform. A surrogate key is a promise I control. On the movies table I still added a UNIQUE constraint on title and release year, because that pair catches an accidental duplicate import even though it is not safe enough to be the key.

For ratings I also chose a surrogate key and enforced one rating per user per movie with a UNIQUE constraint on user_id and movie_id. Ratings is the high-volume table, and a narrow single-column key is easier for later tables to reference. For movie_genres I did the opposite and used a composite key of movie_id and genre_id, because the row has no identity beyond the pair, and the key itself blocks tagging a movie with the same genre twice.

The ON DELETE choices follow who owns the data. Deleting a user cascades to their ratings, because a rating with no author has no meaning and keeping it would leave personal activity behind after an account is removed. Deleting a movie that has ratings is blocked with RESTRICT. A movie is retired by setting is_active to false, so the rating history that feeds averages is never lost by accident. Links in movie_genres cascade when the movie is deleted, since they only describe that movie. Deleting a genre that is still in use is blocked, so no movie is silently left without a category.

I put anything that can be checked on a single row or a single key into the schema. That covers NOT NULL on every column, CHECK constraints on score, release year, and runtime, UNIQUE on genre names, and foreign keys on every link. These rules hold no matter which application, import script, or manual query writes the data, so a bug in one writer cannot bypass them.

Three rules stay with the application. A new rating should only be accepted for an active movie, a rating timestamp should not be in the future, and every movie should have at least one genre. The first needs a lookup in another table at write time. The second depends on the current clock, which makes a CHECK constraint fragile across a dump and restore. The third cannot be true at the moment the movie row is inserted, since its genre links do not exist yet. I could enforce the first with a trigger, but I felt the extra moving parts were not worth it at this stage.

## Reflection

The requirements did not say whether a user can rate the same movie more than once. A different designer could reasonably let ratings pile up as a history, so a user who rated a film 6 in 2024 and 9 in 2026 has two rows, and the current opinion is the latest one.

I chose one rating per user per movie, enforced by a UNIQUE constraint, with a re-rating written as an UPDATE to the existing row. The reads this platform will face most are averages per movie, rating counts, and top-rated lists. With one row per pair, each of those is a plain aggregate over the ratings table. With history, each of those queries would first have to pick every user's latest row, which adds a window function or subquery to the busiest read path, and forgetting it quietly counts some people twice.

The cost lands on the write side and on analysis. An update overwrites the old score, so I cannot answer how one person's opinion changes over time, and rated_at only records the most recent change. I judged questions about a single user's shifting taste to be rarer than questions about a movie's average. If that turns out to be wrong, I would add a separate rating_history table filled by the updates. That keeps the main table small and the common queries simple.
