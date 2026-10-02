# Unit 2 Analysis

## What changed from Unit 1

Building the script forced a few changes to my Unit 1 design, and I updated the ERD, [schema-definition.md](../schema/schema-definition.md), and [constraints.md](../schema/constraints.md) to match.

The biggest change is the score. NUMERIC(3,2) holds at most 9.99, so my Unit 1 scale of 1 to 10 could not be stored in the type this unit asks for. I moved to a half star to five star scale and bounded it with a CHECK from 0.50 to 5.00. The one rating per user per movie decision from Unit 1 is unchanged.

The other changes are smaller. Identifiers became INTEGER instead of BIGINT, timestamps became TIMESTAMP instead of TIMESTAMPTZ, and release year and runtime became INTEGER instead of SMALLINT, to follow the type mapping for this unit. I also added an email column to users, which gives users an alternate key, since display names repeat.

The example for this unit shows a recursive foreign key, and I considered putting one on users as a referral link between two people. I decided against it. Nothing in my requirements asks which user invited which, no question the platform must answer needs it, and none of my other tables has rows that would point at rows of the same table. Adding a column only to demonstrate the syntax would give users a relationship the platform has no use for, so the schema has no recursive foreign key.

I chose not to store any derived value. The average score of a movie changes with every new rating, and ratings is the high-volume table, so a stored average would be rewritten constantly and could drift away from the rows it summarizes. Averages and counts are computed at query time.

## Constraints table

| Foreign key | ON DELETE | Reason |
|---|---|---|
| `ratings.user_id` to `users.user_id` | CASCADE | A rating with no author has no meaning, so it leaves with the account. |
| `ratings.movie_id` to `movies.movie_id` | RESTRICT | Rating history feeds averages and rankings, so a rated movie is retired with `is_active` instead of deleted. |
| `movie_genres.movie_id` to `movies.movie_id` | CASCADE | A genre link only describes its movie and means nothing once the movie is gone. |
| `movie_genres.genre_id` to `genres.genre_id` | RESTRICT | Deleting a genre still in use would leave movies uncategorized without anyone noticing. |

### What each choice governs

When a movie is removed from the platform, usually because a licence ended or a record was entered by mistake, the choice on `ratings.movie_id` decides what happens to everyone who rated it. With RESTRICT, the database refuses the delete while any rating exists, so the movie is retired by setting `is_active` to FALSE. The ratings stay, the averages stay correct, and every user keeps their history. Under CASCADE, one delete would silently erase every rating for the movie, change the rankings, and wipe out the activity of people who did nothing. SET NULL is not available, because `ratings.movie_id` is NOT NULL, and a rating about no movie would be meaningless anyway. An unrated movie can still be deleted, and its genre links go with it through the CASCADE on `movie_genres.movie_id`.

When a user deletes their account, the choice on `ratings.user_id` decides what happens to the ratings they wrote. With CASCADE, the ratings leave with the account, which is what a person asking to be deleted expects, and the averages of the movies they rated shift slightly. Under RESTRICT, a deletion request would be blocked until someone removed every rating by hand. Under SET NULL, the ratings would stay behind with no author, which keeps personal activity in the database after the account is gone.

When a genre is removed, the choice on `movie_genres.genre_id` decides what happens to the movies tagged with it. With RESTRICT, the delete is refused while any movie still carries the genre, so someone has to detach it first. Under CASCADE, the links would disappear and movies would silently lose a category, and some could end up with none.

I checked each of these on a scratch database. Deleting a rated movie and deleting a used genre were both refused, deleting a user removed their ratings, and deleting an unrated movie removed its genre links.

## CHECK constraints

| Constraint | Invalid state it makes unstorable | How that state could otherwise arise |
|---|---|---|
| `chk_ratings_score_range` | A score below 0.50 or above 5.00 | A bug in a client that sends the wrong scale, such as a score out of 10, or a bulk import from a source with a different rating scale. A single 10 among 4s would pull an average up noticeably. |
| `chk_movies_release_year` | A release year before 1888 or after 2100 | A typo such as 2204 for 2024, or a year column filled with a default like 0 when the real value was unknown. |
| `chk_movies_runtime_minutes` | A runtime of zero, a negative runtime, or more than 1000 minutes | A unit mistake, such as seconds entered where minutes are expected, or an empty value converted to 0 by an import script. This would corrupt any filter on movie length. |
| `chk_movies_title_not_blank` | A title made only of spaces | A form that accepts whitespace as input, or a spreadsheet import with a blank cell. NOT NULL alone does not stop this, since a string of spaces is not null. |
| `chk_genres_name_not_blank` | A genre name made only of spaces | The same causes as a blank title. A blank genre would show up as an empty category in any report grouped by genre. |
| `chk_users_display_name_not_blank` | A display name made only of spaces | A signup form that trims nothing, leaving an account that appears with no name in every list. |
| `chk_users_email_format` | An email with no at sign, or with nothing on one side of it | A mistyped address or a field filled with a placeholder. This is a basic shape check only, and it does not prove the address exists. |

I ran each constraint with an invalid insert on a scratch database, and every one was refused with its own constraint name in the error message. That is the reason for naming each one with a prefix.
