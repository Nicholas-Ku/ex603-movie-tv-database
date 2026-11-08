# Unit 5 Analysis

The queries for this unit are in [q5_1.sql](../queries/unit5/q5_1.sql), [q5_2.sql](../queries/unit5/q5_2.sql) and [q5_3.sql](../queries/unit5/q5_3.sql). The producers are movies, the events are ratings, and the producers from Assignment 4 are movies 2 and 3. Producers are reported by `movie_id`.

## Task 5.1: Connect producers to their data

### What the three-table join could power

The three-table join fits a review queue for the trust and safety team. In Unit 4 I suggested that a reviewer check who submitted the spam ratings on movies 2 and 3, and this join is the report that would let them do it. Each row would show the rating, the user who submitted it, the movie title, and the date and time. A reviewer could then open a user from the list without looking up three tables by hand. The same join could also drive an activity feed on a movie page, with the newest ratings first.

I checked that the join loses nothing. The join returns 200 rows and the ratings table holds 200 rows, because both foreign keys on `ratings` are NOT NULL and point at rows that must exist.

### Why the junction table matters

A movie can have several genres and a genre can belong to several movies, so a single genre column on `movies` cannot hold the relationship. Movie 2 has three genres (Drama, Comedy and Thriller) and Comedy is on five movies (2, 3, 5, 10 and 11). The `movie_genres` table stores one row for each movie and genre pair, and the query reaches the genre names by joining movies to the junction and the junction to genres.

Without the junction table, the choices would be a column for every genre or a list of genres stored inside one column. A column for every genre means changing the table whenever a new genre is added. A list in one column means searching text to find the Comedy movies, and the database could no longer enforce that a tagged genre exists. I think either choice would make the Comedy question much harder to answer correctly.

### What the queries showed about the Assignment 4 producers

Movies 2 and 3 are both Comedy, and Comedy is the only genre they share. I wouldn't read much into that. Comedy is on 5 of the 15 movies, and with two movies and five genres, sharing one genre is easy to do by chance.

I noticed something more specific in the self join. Movies 2 and 3 were both released in 2023, and so were movies 1, 4 and 5. Those five movies have 64 ratings and 7 spam withdrawals, which is 10.9 percent. The other eight movies with ratings have 136 ratings and 5 spam withdrawals, which is 3.7 percent. So 7 of the 12 spam withdrawals on the platform land on movies released in 2023. Movie 5 is also a 2023 release and has no spam withdrawals in 18 ratings, so the year does not hold for every movie.

Activity level does not explain the two producers. Movie 2 has 16 ratings and movie 3 has 13, which is close to the platform average of about 15 per movie. Movie 4 has the lowest volume, with 6 ratings, and its rate of 16.7 percent rests on a single spam withdrawal. With only 12 spam withdrawals across the whole platform, I would treat the 2023 pattern as a lead for a reviewer to look into and not as a finding.

## Task 5.2: Find records that joins may exclude

### Which producers the inner join excluded

The LEFT JOIN returns 15 producers and the INNER JOIN returns 13, so the inner join excludes 2 producers. They are movie 14 (`Title_14`, India, released 2013) and movie 15 (`Title_15`, UK, released 2008). The count uses distinct `movie_id` values, so a movie with many ratings is counted once.

### What it means when a producer has no events

A producer with no events has no row in `ratings`. The table shows that and nothing more. Movies 14 and 15 are marked available, and they were added in February and April of 2022. Eleven of the other movies were added after movie 14 and ten were added after movie 15, and all of the rating activity falls in 2023, so these two are not newer than the rest of the catalog.

Some possible explanations are below, and I can't tell from the data which one is right.

- Users may not be able to find them. Neither movie has a genre tag, but a missing tag alone does not explain it, because movie 13 also has no genre tag and has 11 ratings.
- They may be hidden from users in some places, even though the table marks them as available.
- They may have been loaded by mistake or as test records that no one ever meant to show.
- They may not be offered in the regions where most of the platform's users are, or not offered anywhere.

### How an inner join gives an incomplete picture

A report built only on an inner join would describe a platform of 13 movies. The per-movie breakdown in Unit 4 did exactly that. It covered 13 movies while the table holds 15, and nothing in the output said that two were left out. A reader would take the 13 as the catalog. Any figure about the catalog, such as the share of movies with a spam problem or the average number of ratings per movie, would use the wrong denominator. A missing row also leaves nothing on the screen to question, which is why I think it is the hardest kind of error to notice.

### Why leadership might want to know

A producer that has never had an event is still part of the catalog. It may cost money to host or license, and it earns no ratings in return. It could also be a sign of a problem that affects other producers, such as a movie that cannot be found because of how the catalog is built. Counting these producers is the first step to finding out which of those is true.

### What leadership could do

I would start with the checks that cost the least. The catalog team can confirm whether movies 14 and 15 appear on the site and whether they have genre tags. If they are hidden or untagged, tagging them and watching for ratings over a few weeks would show whether visibility was the cause. If they are visible and tagged and still get no ratings after that, leadership can decide whether to keep paying for them. If they turn out to be test or mistaken records, they can be retired by setting `is_available` to false.

### What the data shows and what needs more investigation

The data shows that movies 14 and 15 have zero ratings out of 200, that they are marked available, that both were added in 2022, that neither has a genre tag, and that the two approaches in Part C (NOT EXISTS and EXCEPT) return exactly these two producers. The FULL OUTER JOIN also shows that no rating points to a movie that does not exist.

The table does not say why the two movies have no ratings. I can't tell from it whether users can see them, whether they are licensed for the regions where users are, whether anyone intended them to be shown, or whether the missing genre tags are a cause or a coincidence. Answering those questions needs someone who can look at the site and at the catalog team's records.

### Part B and Part C observations

The RIGHT JOIN returns the same 15 producers as the LEFT JOIN, and I checked that instead of assuming it. The row counts match at 15, and EXCEPT finds 0 rows in either direction. The FULL OUTER JOIN returns 202 rows, which is 200 matched rows and 2 movies without ratings. It adds one thing the other two cannot show in the same pass, which is the number of ratings without a movie. That count is 0, so no rating is orphaned.

NOT EXISTS and EXCEPT both return movies 14 and 15, and neither finds a producer the other misses. They differ in how they work. NOT EXISTS asks, one movie at a time, whether any rating matches, and it can return any column of `movies`. EXCEPT subtracts the list of rated `movie_id` values from the list of all `movie_id` values and returns only the columns it compares.

## Task 5.3: Understand join performance and execution plans

### Cartesian product on this platform

I would not use a Cartesian product to answer a question about ratings, because pairing every row with every row does not describe anything that happened. It does help with coverage questions. The CROSS JOIN of the 5 rows in `genres` with the 15 rows in `movies` returns 75 rows, which equals 5 x 15. Only 25 of those 75 pairs exist in `movie_genres`, so the other 50 are movie and genre combinations that nobody has tagged. Pairing the full set first and then matching it to the real tags is how I found that number.

A second use is a report grid. I crossed the 5 genres with the 5 device countries and joined the actual rating counts onto the 25 combinations. The platform has no table of countries, so that list of countries comes from `ratings`. In this data every one of the 25 cells has ratings, and the smallest is Documentary from the UK with 2. If a new genre or country had no ratings yet, a grid built this way would still show it with a 0, while a plain join would leave the row out.

The same behavior makes a Cartesian product a warning sign in other places. If I forgot the ON clause in the three-table join, the result would be 200 x 30 x 15 = 90,000 rows. A result far larger than the biggest table usually means a missing join condition.

### The complete execution plan

This is the plan from `EXPLAIN ANALYZE` on the three-table join from 5.1A. The row counts and the plan shape are the same every time I run it, and the timings change slightly from run to run.

```
                                                                   QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------------------------------
 Limit  (cost=33.66..33.71 rows=20 width=536) (actual time=0.195..0.197 rows=20 loops=1)
   ->  Sort  (cost=33.66..34.16 rows=200 width=536) (actual time=0.194..0.196 rows=20 loops=1)
         Sort Key: r.rated_at DESC, r.rating_id DESC
         Sort Method: top-N heapsort  Memory: 27kB
         ->  Nested Loop  (cost=12.40..28.34 rows=200 width=536) (actual time=0.057..0.151 rows=200 loops=1)
               ->  Hash Join  (cost=12.25..17.80 rows=200 width=278) (actual time=0.042..0.085 rows=200 loops=1)
                     Hash Cond: (r.user_id = u.user_id)
                     ->  Seq Scan on ratings r  (cost=0.00..5.00 rows=200 width=24) (actual time=0.015..0.029 rows=200 loops=1)
                     ->  Hash  (cost=11.00..11.00 rows=100 width=262) (actual time=0.019..0.019 rows=30 loops=1)
                           Buckets: 1024  Batches: 1  Memory Usage: 10kB
                           ->  Seq Scan on users u  (cost=0.00..11.00 rows=100 width=262) (actual time=0.008..0.010 rows=30 loops=1)
               ->  Memoize  (cost=0.15..0.41 rows=1 width=262) (actual time=0.000..0.000 rows=1 loops=200)
                     Cache Key: r.movie_id
                     Cache Mode: logical
                     Hits: 187  Misses: 13  Evictions: 0  Overflows: 0  Memory Usage: 2kB
                     ->  Index Scan using movies_pkey on movies m  (cost=0.14..0.40 rows=1 width=262) (actual time=0.001..0.001 rows=1 loops=13)
                           Index Cond: (movie_id = r.movie_id)
 Planning Time: 6.272 ms
 Execution Time: 0.252 ms
(19 rows)
```

### Which join algorithms the plan uses

The plan uses two join algorithms and no Merge Join. A Hash Join combines `ratings` with `users` on `user_id`. A Nested Loop then takes each of those 200 joined rows and looks up its movie, using an Index Scan on `movies_pkey`.

### What in the plan explains those choices

The Hash Join builds its hash table from `users`, the smaller side, and then reads `ratings` once and checks each rating against the table. The hash holds 30 users in 10kB in a single batch, so it never leaves memory. Reading `ratings` with a Seq Scan makes sense because the table has only its primary key on `rating_id`, so there is no index on `user_id` or `movie_id` to use instead. The table is also only 3 pages, and I think reading 3 pages is cheaper than going through an index even if one existed.

The Nested Loop for `movies` works because `movies.movie_id` is the primary key, so each lookup is one index probe that returns one row. The Memoize node saves the repeated lookups. It records 187 hits and 13 misses, and 13 is the number of movies that have ratings. The index is searched 13 times instead of 200.

I noticed that one estimate in the plan is wrong. The plan expects 100 rows from `users`, and the table has 30. I think the cause is that the table has never had statistics gathered, since the catalog shows no row estimate for `users` or `movies` and no recorded analyze run. The plan is still reasonable at this size, but I wouldn't count on that if the estimates were this far off on a larger table.

### What I predict will slow down as the data grows

The part I expect to become slower first is the Seq Scan on `ratings` and the Sort above the joins. `ratings` is the table that grows fastest, and nothing lets the plan skip any of it. The Hash Join must read every rating, the Nested Loop must probe once per rating, and the Sort must look at every joined row to find the newest 20, because there is no index on `rated_at`. At 200 rows this takes 0.252 ms, but the work grows with the number of ratings. The hash table for `users` is the second part to watch, because it has to fit in memory.

### Why it is useful to understand the join algorithms

The algorithm shows where a query spends its time. A Hash Join is limited by how big the hash table gets, a Nested Loop is limited by how many times it repeats its inner lookup, and a Merge Join is limited by sorting. When a query slows down, reading the plan tells me which of those to fix. It also tells me whether adding an index will help, since an index only matters to the algorithms that can use it.

### What could make another algorithm more appropriate

A larger `users` table could push the hash table past the memory limit, so the Hash Join would split into several batches and write to disk, and a Merge Join over sorted inputs could then cost less. An index on `ratings.user_id` or `ratings.movie_id` would help a query for one user or one movie, because the plan could use a Nested Loop that reads only those ratings. If `ratings` pointed at thousands of different movies and not 13, Memoize would hit its cache far less and the Nested Loop for `movies` would cost more.

## Reflection

The plan for my three-table join used a Hash Join for `ratings` and `users`, and a Nested Loop with an index lookup for `movies`. Both choices depend on how small the tables are, so I expect the plan to change as the data grows.

Table size is the biggest factor. The hash table for `users` holds 30 rows in 10kB, so it stays in memory. If `users` grew to millions of rows, the hash table could exceed the memory limit and spill to disk in several batches, and a Merge Join over sorted inputs could become cheaper.

Indexes are the second factor. `ratings` has only its primary key, so the plan reads the whole table. An index on `user_id` or `movie_id` would let a query for one user or one movie skip most of the table. An index on `rated_at` could let the sort stop early.

The number of matching rows is the third factor. The ratings point at only 13 different movies, which is why Memoize hit its cache 187 times out of 200. If they pointed at thousands of movies, the cache would help much less.

I also noticed that the plan expected 100 users and the table has 30, because no statistics were gathered. Bad estimates can lead the planner to a worse algorithm, so I would keep statistics current as the tables grow.
