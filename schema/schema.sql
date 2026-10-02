-- =================================================================
-- EX 603 Assignment 2 - schema.sql
-- Theme: Movie / TV
-- Author: Nicholas Ku
-- Target: PostgreSQL 14+
-- =================================================================
--
-- Creation order. I worked this out from the ERD before writing any
-- SQL. A table can only be created after every table it points at,
-- so the tables with no outgoing arrows go first.
--   1. users          points at nothing
--   2. movies         points at nothing
--   3. genres         points at nothing
--   4. ratings        points at users and movies
--   5. movie_genres   points at movies and genres
--
-- Derived values: I did not store any. The average score of a movie
-- changes every time someone rates it, and ratings is the table that
-- grows fastest. A stored average would need rewriting constantly and
-- could drift away from the rows it summarizes, so I compute averages
-- and counts at query time instead.
-- =================================================================

-- Reset. I drop in reverse creation order so no dependency blocks a
-- drop. This is what lets me run the script again without cleanup.

DROP TABLE IF EXISTS movie_genres CASCADE;
DROP TABLE IF EXISTS ratings      CASCADE;
DROP TABLE IF EXISTS genres       CASCADE;
DROP TABLE IF EXISTS movies       CASCADE;
DROP TABLE IF EXISTS users        CASCADE;

-- ----------------------------------------------------------------
-- 1. users (actor)
-- This one goes first because it references nothing.
-- ----------------------------------------------------------------
CREATE TABLE users (
    user_id      INTEGER GENERATED ALWAYS AS IDENTITY,
    display_name VARCHAR(100) NOT NULL,
    email        VARCHAR(255) NOT NULL,
    joined_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_users PRIMARY KEY (user_id),
    -- display names repeat, so email is the alternate key
    CONSTRAINT uq_users_email UNIQUE (email),
    -- NOT NULL does not stop a name made only of spaces, so I check it
    CONSTRAINT chk_users_display_name_not_blank
        CHECK (length(trim(display_name)) > 0),
    -- a basic shape check, it does not prove the address exists
    CONSTRAINT chk_users_email_format
        CHECK (email LIKE '%_@_%')
);

-- ----------------------------------------------------------------
-- 2. movies (producer)
-- It references nothing, so it can be created early.
-- is_active is how I retire a movie. A movie that already has
-- ratings gets set to FALSE instead of being deleted.
-- ----------------------------------------------------------------
CREATE TABLE movies (
    movie_id        INTEGER GENERATED ALWAYS AS IDENTITY,
    title           VARCHAR(200) NOT NULL,
    release_year    INTEGER      NOT NULL,
    runtime_minutes INTEGER      NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    CONSTRAINT pk_movies PRIMARY KEY (movie_id),
    -- titles repeat, so the pair is only a guard against duplicate
    -- imports and not the key
    CONSTRAINT uq_movies_title_year UNIQUE (title, release_year),
    CONSTRAINT chk_movies_title_not_blank
        CHECK (length(trim(title)) > 0),
    -- 1888 is the earliest surviving film, 2100 leaves room for
    -- announced releases
    CONSTRAINT chk_movies_release_year
        CHECK (release_year BETWEEN 1888 AND 2100),
    -- the upper bound catches seconds typed in where minutes belong
    CONSTRAINT chk_movies_runtime_minutes
        CHECK (runtime_minutes BETWEEN 1 AND 1000)
);

-- ----------------------------------------------------------------
-- 3. genres (catalog)
-- It references nothing, so the order between this and movies does
-- not matter.
-- ----------------------------------------------------------------
CREATE TABLE genres (
    genre_id INTEGER GENERATED ALWAYS AS IDENTITY,
    name     VARCHAR(50) NOT NULL,
    CONSTRAINT pk_genres PRIMARY KEY (genre_id),
    CONSTRAINT uq_genres_name UNIQUE (name),
    CONSTRAINT chk_genres_name_not_blank
        CHECK (length(trim(name)) > 0)
);

-- ----------------------------------------------------------------
-- 4. ratings (event)
-- This comes after users and movies because it points at both.
-- A user can rate a movie once (uq_ratings_user_movie). If they
-- change their mind, the existing row gets updated.
-- ----------------------------------------------------------------
CREATE TABLE ratings (
    rating_id INTEGER GENERATED ALWAYS AS IDENTITY,
    user_id   INTEGER      NOT NULL,
    movie_id  INTEGER      NOT NULL,
    rated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    score     NUMERIC(3,2) NOT NULL,
    CONSTRAINT pk_ratings PRIMARY KEY (rating_id),
    CONSTRAINT uq_ratings_user_movie UNIQUE (user_id, movie_id),
    -- the ratings go when the account goes
    CONSTRAINT fk_ratings_user
        FOREIGN KEY (user_id) REFERENCES users (user_id)
        ON DELETE CASCADE,
    -- a rated movie cannot be deleted, retire it with is_active
    CONSTRAINT fk_ratings_movie
        FOREIGN KEY (movie_id) REFERENCES movies (movie_id)
        ON DELETE RESTRICT,
    -- NUMERIC(3,2) holds up to 9.99, so the CHECK is what keeps the
    -- score on the half star to five star scale
    CONSTRAINT chk_ratings_score_range
        CHECK (score BETWEEN 0.50 AND 5.00)
);

-- Averages and counts filter on movie_id alone. The unique index on
-- (user_id, movie_id) cannot help with that, because user_id comes
-- first, so this index covers it.
CREATE INDEX idx_ratings_movie_id ON ratings (movie_id);

-- ----------------------------------------------------------------
-- 5. movie_genres (junction)
-- This goes last because it points at movies and genres. The primary
-- key is the pair of foreign keys, so a movie cannot get the same
-- genre twice.
-- ----------------------------------------------------------------
CREATE TABLE movie_genres (
    movie_id INTEGER NOT NULL,
    genre_id INTEGER NOT NULL,
    CONSTRAINT pk_movie_genres PRIMARY KEY (movie_id, genre_id),
    -- the link only describes the movie, so it goes with the movie
    CONSTRAINT fk_movie_genres_movie
        FOREIGN KEY (movie_id) REFERENCES movies (movie_id)
        ON DELETE CASCADE,
    -- a genre that is still in use cannot be deleted
    CONSTRAINT fk_movie_genres_genre
        FOREIGN KEY (genre_id) REFERENCES genres (genre_id)
        ON DELETE RESTRICT
);

-- The primary key covers lookups by movie. This index covers lookups
-- by genre.
CREATE INDEX idx_movie_genres_genre_id ON movie_genres (genre_id);
