# Relation Schemas (Task 1.1)

Theme: Movie / TV. The five roles map to relations as follows.

| Role | Relation |
|---|---|
| actor | `users` |
| producer | `movies` |
| event | `ratings` |
| catalog | `genres` |
| junction | `movie_genres` |

Domains use PostgreSQL types, as built in [schema.sql](schema.sql). Primary key attributes are marked PK and foreign key attributes are marked FK.

## users (actor)

A person who rates movies on the platform.

| Attribute | Domain | Notes |
|---|---|---|
| `user_id` | INTEGER, system generated (identity) | PK |
| `display_name` | VARCHAR(100) | Required. Not unique, because two people can choose the same name. |
| `email` | VARCHAR(255) | Required. Unique, with a basic format check. |
| `joined_at` | TIMESTAMP | Required. Defaults to the time of insert. |

**Primary key:** `user_id`

**Alternate key:** `email`

## movies (producer)

A title in the catalogue that users can rate.

| Attribute | Domain | Notes |
|---|---|---|
| `movie_id` | INTEGER, system generated (identity) | PK |
| `title` | VARCHAR(200) | Required. |
| `release_year` | INTEGER, 1888 to 2100 | Required. |
| `runtime_minutes` | INTEGER, 1 to 1000 | Required. The numeric attribute used for filtering. |
| `is_active` | BOOLEAN | Required. Defaults to TRUE. FALSE means the movie is retired and no longer open for new ratings. |

**Primary key:** `movie_id`

## ratings (event)

One rating action by one user on one movie. This is the high-volume fact table.

| Attribute | Domain | Notes |
|---|---|---|
| `rating_id` | INTEGER, system generated (identity) | PK |
| `user_id` | INTEGER | FK to `users.user_id`. Required. |
| `movie_id` | INTEGER | FK to `movies.movie_id`. Required. |
| `rated_at` | TIMESTAMP | Required. Defaults to the time of insert. |
| `score` | NUMERIC(3,2), 0.50 to 5.00 | Required. The metric that gets aggregated. |

**Primary key:** `rating_id`

**Alternate key:** (`user_id`, `movie_id`), meaning a user holds at most one rating per movie.

## genres (catalog)

A category that classifies movies.

| Attribute | Domain | Notes |
|---|---|---|
| `genre_id` | INTEGER, system generated (identity) | PK |
| `name` | VARCHAR(50) | Required. Unique. |

**Primary key:** `genre_id`

**Alternate key:** `name`

## movie_genres (junction)

The many-to-many link between movies and genres.

| Attribute | Domain | Notes |
|---|---|---|
| `movie_id` | INTEGER | FK to `movies.movie_id`. Part of the PK. |
| `genre_id` | INTEGER | FK to `genres.genre_id`. Part of the PK. |

**Primary key:** composite (`movie_id`, `genre_id`)

## Relationships and cardinality

| Relationship | Cardinality | Meaning |
|---|---|---|
| `users` to `ratings` | one to many (0..*) | A user submits zero or more ratings. Every rating belongs to exactly one user. |
| `movies` to `ratings` | one to many (0..*) | A movie receives zero or more ratings. Every rating is for exactly one movie. |
| `movies` to `movie_genres` | one to many (0..*) | A movie carries zero or more genre links. |
| `genres` to `movie_genres` | one to many (0..*) | A genre tags zero or more movies. |
| `movies` to `genres` | many to many | Resolved through `movie_genres`. |
| `users` to `movies` | many to many | Resolved through `ratings`, with at most one rating per pair. |
