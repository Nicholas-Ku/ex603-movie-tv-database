# Integrity Constraints (Task 1.3)

Every constraint below is meant to be declared in the schema, so that invalid data is rejected no matter which application, script, or manual query writes it. The DDL itself comes in Unit 2.

## Primary keys

| Relation | Key | Justification |
|---|---|---|
| `users` | `user_id` | Display names repeat, so a generated key is the only stable identity. |
| `movies` | `movie_id` | Titles repeat across remakes and unrelated films. |
| `ratings` | `rating_id` | A narrow single-column key is easy for later tables to reference. Uniqueness of the user and movie pair is enforced separately. |
| `genres` | `genre_id` | Keeps the key stable if a genre is renamed. The name is protected by a UNIQUE constraint instead. |
| `movie_genres` | (`movie_id`, `genre_id`) | The row has no identity beyond the pair. The composite key also blocks tagging a movie with the same genre twice. |

## Foreign keys and ON DELETE behavior

| Foreign key | ON DELETE | Justification |
|---|---|---|
| `ratings.user_id` to `users.user_id` | CASCADE | A rating with no author has no meaning. Removing an account should also remove the activity tied to it. |
| `ratings.movie_id` to `movies.movie_id` | RESTRICT | Rating history feeds averages and rankings, so deleting a rated movie must not silently erase it. A movie is retired by setting `is_active` to FALSE. Only a movie with no ratings can be deleted. |
| `movie_genres.movie_id` to `movies.movie_id` | CASCADE | The link row only describes the movie, so it should disappear with it. |
| `movie_genres.genre_id` to `genres.genre_id` | RESTRICT | Deleting a genre still in use would leave movies uncategorized without anyone noticing. The genre has to be detached from its movies first. |

ON UPDATE keeps the default (NO ACTION), because surrogate keys are never changed.

## NOT NULL

| Relation | Columns |
|---|---|
| `users` | `display_name`, `joined_at` |
| `movies` | `title`, `release_year`, `runtime_minutes`, `is_active` |
| `ratings` | `user_id`, `movie_id`, `rated_at`, `score` |
| `genres` | `name` |
| `movie_genres` | `movie_id`, `genre_id` (implied by the primary key) |

Every column in the schema is required. Nothing in the requirements calls for an unknown value, so NULL never needs to carry meaning here. A missing score, for instance, would be a rating that says nothing.

## UNIQUE

| Constraint | Justification |
|---|---|
| `genres(name)` | Two genres with the same name would split one category in half and break counts by genre. |
| `ratings(user_id, movie_id)` | A user holds at most one rating per movie, so averages count each person once. A re-rating updates the existing row. |
| `movies(title, release_year)` | Catches an accidental duplicate import of the same film. The pair is not a safe primary key, but it is a useful guard. |

## CHECK

| Constraint | Rule | Justification |
|---|---|---|
| `ratings.score` | `score BETWEEN 1 AND 10` | A score outside the scale would distort every average. |
| `movies.release_year` | `release_year BETWEEN 1888 AND 2100` | The first surviving film dates to 1888. The upper bound allows announced future releases. |
| `movies.runtime_minutes` | `runtime_minutes BETWEEN 1 AND 1000` | A zero or negative runtime is impossible, and the upper bound catches unit mistakes such as seconds entered as minutes. |
| `genres.name` | `length(trim(name)) > 0` | Blocks a genre made of blank space. |
| `users.display_name` | `length(trim(display_name)) > 0` | Blocks a blank display name. |
| `movies.title` | `length(trim(title)) > 0` | Blocks a blank title. |

## DEFAULT

| Column | Default |
|---|---|
| `users.joined_at` | `now()` |
| `ratings.rated_at` | `now()` |
| `movies.is_active` | `TRUE` |

## Supporting indexes (planned for Unit 2)

The primary key on `movie_genres` covers lookups by movie. A second index on `movie_genres(genre_id)` covers lookups by genre. An index on `ratings(movie_id)` covers per-movie aggregates, because the UNIQUE index on (`user_id`, `movie_id`) only helps when `user_id` is known.

## Rules intentionally left to the application

| Rule | Why it is not in the schema |
|---|---|
| A new rating can only be added for an active movie. | It needs a lookup in another table at write time, which means a trigger. |
| `rated_at` must not be in the future. | A CHECK against `now()` is not stable across dump and restore. |
| Every movie must have at least one genre. | At the moment the movie row is inserted, no genre links exist yet, so a database rule would reject every insert. |
