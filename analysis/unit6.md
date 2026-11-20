# Unit 6 Analysis

The queries for this unit are in [q6_1.sql](../queries/unit6/q6_1.sql), [q6_2.sql](../queries/unit6/q6_2.sql) and [q6_3.sql](../queries/unit6/q6_3.sql). Producers are movies, events are ratings, and the metric is `ratings.score`. Producers are reported by `movie_id`.

## Task 6.1: Compute across a window without collapsing

### A question that needs each rating next to its movie's average

The question I asked is which ratings sit more than 2 points below their own movie's average. A score of 1.0 means something different on movie 11, which averages 2.09, than on movie 5, which averages 3.51. The comparison only works if the rating and its movie's average are on the same row.

The window version returns all 200 ratings with the movie average beside each one. The GROUP BY version returns 13 rows, one per rated movie. I checked that the two compute the same thing. All 13 movies have the same average and the same count in both versions. The difference is what's left in the output. GROUP BY keeps the average and drops the 200 ratings, along with their status, timestamp and score, so there is nothing left to compare against the average. To answer the question with GROUP BY alone, I'd need to join the grouped result back to `ratings`, which is the step the window function saves.

The answer is 25 ratings. Twenty of them are withdrawn ratings, which all carry the 0.5 score I noticed in Unit 4, so they sit far below almost any average. The other 5 are published ratings between 0.8 and 1.1, and three of them are on movie 10. The five published ratings are the ones I'd hand to a reviewer, because they are real scores that disagree strongly with everyone else who rated the same movie.

### Which ranking a leaderboard should use

The feature I have in mind is a Most Rated list on the home page, showing movies by how many ratings they received. The ranking query shows four ties. The clearest one is movies 5 and 7, which both have 18 ratings.

I'd use RANK for the leaderboard. Under RANK, movies 5 and 7 both get 4th place, and the next movie, movie 12, is listed 6th. The course notes describe RANK as the right fit for competitive standings and leaderboards (lesson 1.2), and I agree for this reason. Under RANK, a movie's position shows a reader how many movies are ahead of it. Movie 12 really does have five movies ahead of it.

ROW_NUMBER would put movie 5 above movie 7. Nothing about the movies decides that, only the tiebreaker in my ORDER BY, which is movie_id. A smaller ID would win every tie, and a studio looking at the list would have a fair reason to complain. DENSE_RANK keeps the tie but closes the gaps, so movie 4 shows up 10th even though 12 movies are ahead of it. DENSE_RANK fits tiers better than positions, and a leaderboard is about position.

### What NTILE did with the tie

NTILE(4) put movie 5 in band 1 and movie 7 in band 2, even though both have 18 ratings. NTILE splits by row count, so with 15 movies the bands hold 4, 4, 4 and 3 movies, and the line after the fourth row fell between the two tied movies. The only thing that put movie 5 on the upper side was its smaller movie_id. If the bands were used to decide something, such as which movies get promoted, two movies with identical activity would be treated differently. Bands defined by value with CASE WHEN would keep tied movies together.

## Task 6.2: Compare each row to its neighbors

### What a large delta tells someone

I followed movie 2, since it was one of the two high-failure movies in Units 4 and 5. Its largest changes are -2.9 on 17 December, +2.8 on 12 April and +2.7 on 11 August. The first two involve a withdrawn rating, and every withdrawn rating has a score of exactly 0.5. A drop of almost 3 points on 17 December doesn't mean a viewer suddenly disliked the movie, because the rating behind the drop was withdrawn and carries the placeholder score.

Across all movies, 67 of the 187 rating-to-rating changes are 2.5 points or more, which is half the scale. Of those, 28 involve a withdrawn rating, and 39 are between two ratings that were never withdrawn. So a large delta on this platform means one of two things, and the response is different for each. If a withdrawn rating is involved, the trust and safety team already handled it, and the useful follow-up is to find out where the 0.5 score comes from, because it makes every average look worse than it is. If two real ratings disagree by 3 points, the movie divides its audience. I'd show its score distribution next to its average on the movie page, so a viewer can see the split instead of a middling number.

### Why a running total answers what a plain SUM can't

A plain SUM gives one number, 200 ratings for 2023. The running total keeps every day and shows how the platform got to 200. I set a target of 240 ratings for the year, or 20 a month. The running total was ahead of that pace after January and February, fell 16 short by the end of April, and never caught up. The year finished at 83 percent of the target, 40 ratings short.

The shape of the running total matters more than the final number, because the shortfall came from two different problems. March and April alone lost 18 ratings against the target, since only 11 ratings arrived in each of those months, which turned a lead of 2 into a gap of 16. After April, seven of the eight remaining months came in under 20, and those smaller misses added up to another 24. A plain SUM of 200 can't separate a sudden drop from a slow leak, and the two need different fixes.

### Why a window of 30 ratings

The moving average is the spam rate over the last 30 ratings. I counted ratings and not days, because ROWS counts rows, and only 155 of the 362 days in the data have any ratings at all. A 30-row window over days would cover much more than 30 days at some points of the year and less at others.

I picked 30 because the platform gets about 17 ratings a month, so 30 ratings is a little under two months. At the platform's 6 percent spam rate, 30 ratings should hold about two spam withdrawals, so one more or one fewer moves the rate by 3.3 points. I also ran a 10-rating window to compare. The 10-rating window only ever shows 0, 10 or 20 percent, and it jumps 10 points every time a single spam rating enters or leaves, which makes the platform look like it has a crisis and a recovery several times a month. The 30-rating window stays between 0 and 10 percent, with its highest readings between May and September, a stretch at 0 from mid October to mid December, and a final value of 6.7 percent after two spam withdrawals in December. The trade-off is that a 30-rating window reacts more slowly, so a real spike would take a few weeks to show. The window is also trailing, so it only uses ratings that already exist, which is what a live dashboard needs.

### ROWS compared with RANGE

ROWS counts physical rows, so two ratings on the same day get different running counts, one after the other. RANGE, which is the default frame when there is an ORDER BY, includes every row with the same ORDER BY value as the current row, so all ratings on the same day get the day's full count. On 8 January the three ratings get 4, 5 and 6 under ROWS and 6, 6 and 6 under RANGE.

### What the gap means

I measured each gap against the movie's own usual spacing, and kept gaps at least 4 times longer than usual, which returned four movies. Movie 9 has the longest gap, 112 days from 5 January to 28 April, and movies 5, 11 and 12 each went about three months without a rating in the same part of the year. All four gaps cover 8 March to 27 April.

I think this is a real stop in activity and not lost data, but I'm not fully sure. If the pipeline had broken, ratings would have stopped for every movie, and they didn't. While each of these movies was quiet, 11 or 12 other movies were still being rated, between 40 and 61 ratings per gap, so the platform kept recording. What did happen is that the whole platform slowed down. Only 11 ratings arrived in each of March and April, and in the seven weeks all four gaps share, the platform recorded 18 ratings across 7 movies. Six of the 13 rated movies had no ratings at all in that stretch.

What I can't tell is why those particular movies went quiet. Movie 9 is marked unavailable today, so it may have been taken down and put back. The table only stores the current value of `is_available` and not its history, so I can't check. I also can't rule out a partial recording problem that affected some movies and not others. Each explanation needs a different response. A real slowdown needs a look at what changed for users in March, a data problem needs the ingestion logs for those weeks, and an availability change needs the catalog team's records. I'd start with the catalog team, because one question about the availability history of movies 5, 9, 11 and 12 is the cheapest way to tell the three apart.

## Task 6.3: Build the reporting patterns

### The feature top-N would power

The top-N query would power a Top Reviews strip on each movie page, showing the three highest published ratings with the newest first when scores tie. I only ranked published ratings. Withdrawn ratings all carry the 0.5 placeholder, and flagged ratings are still being reviewed, so neither belongs in front of a viewer.

I think three is the right number because of what the data looks like. Twelve of the 13 movies have a best published score of 5.0, so a strip with one review would show a 5.0 on almost every page and tell a viewer nothing about the movie. Three reviews give more than one opinion and still fit in a single row on a phone. Ten would be too many for this catalog. Movie 4 has only 4 published ratings, and movies 1, 3, 9 and 13 have 9 or fewer, so five movies couldn't fill ten slots, and a half-empty list makes a movie look unpopular.

Ties at third place are common. Movies 5, 7, 8 and 10 tie at 5.0 and movie 12 ties at 4.5. I used ROW_NUMBER so the strip always gets exactly three rows. RANK would keep every tied rating and return up to 6 rows for movie 5 and movie 10, which breaks a layout with three slots. One thing I noticed is that for five movies all three slots are 5.0, so the strip looks the same on each of those pages. Pairing the strip with the most recent critical review could make it more useful, but that would be a separate feature.

### What a large month-over-month change means

The largest change in volume is March, which fell 47.6 percent from February (21 ratings to 11). Volume stayed at 11 in April and jumped 54.5 percent to 17 in May. A drop that size on a ratings platform means people stopped rating, and the first thing to check is whether they could still find the movies. Task 6.2 found four movies that went quiet in exactly those weeks, so the catalog team should check what was available in March and April before anyone treats the drop as a change in what users want.

The spam rate swings much harder. March reached 18.2 percent and April fell to 0, but March had only 2 spam withdrawals out of 11 ratings. In a month that small, one spam withdrawal moves the rate by about 9 points. A rule that alerts on a jump in the monthly rate would go off over a single rating several times a year, and people would learn to ignore it. I'd have the trust and safety lead review a month's spam withdrawals only when the month has at least 3 of them or the 30-rating rolling rate from Task 6.2 goes above 10 percent, and report the quarterly rate to leadership. By quarter the rate fell from 7.5 to 6.3, 5.9 and 4.2 percent, which is a trend someone can act on.

## Reflection

The rolling spam rate over the last 30 ratings, from Task 6.2, is easy with a window function and awkward with GROUP BY alone. With a window, I wrote AVG of a 0 or 1 spam flag over ROWS BETWEEN 29 PRECEDING AND CURRENT ROW. Every rating keeps its row and gains the spam rate of the 30 ratings ending at it, in one pass.

GROUP BY can't build these windows directly, because GROUP BY puts each row into exactly one group, and the windows overlap. Rating 100 sits in the window of rating 100 and in the windows of the 29 ratings after it. To get there with GROUP BY, I'd have to join ratings to itself, pairing each rating with every rating among the 29 before it, and then group by the first rating and average the spam flag. Finding the 29 before it needs a row number, which is itself a window function, or a correlated subquery that counts earlier ratings for every row. The self-join also builds about 30 rows for every rating before collapsing them, so the work grows with the window size.

The comparison also showed me why keeping the rows matters for a report like this. The 30-rating rate ends the year at 6.7 percent, and I could see exactly which two December spam withdrawals put it there. A GROUP BY by month would have given me a single December number, without the rows that explain it.
