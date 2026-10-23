# Unit 4 Analysis

The queries for this unit are in [q4_1.sql](../queries/unit4/q4_1.sql) and [q4_2.sql](../queries/unit4/q4_2.sql). The failure state is the same as in Unit 3, a rating that was withdrawn as spam. The metric is `ratings.score`, and producers are movies, reported by `movie_id`.

## Task 4.1: Measure the platform

### What the baseline showed

The 200 ratings have a total score of 569.3 and an average of 2.85, with a minimum of 0.5 and a maximum of 5.0. They come from 30 distinct users and cover 13 distinct movies. The minimum is not zero, but it still looked wrong to me, so I split the scores by status. All 34 withdrawn ratings have a score of exactly 0.5, and no published or flagged rating does. Published ratings average 3.32, so the 2.85 platform average is being pulled down by the withdrawn ratings. I wasn't sure whether a user really gave 0.5 on each of them or whether the platform fills in that value when a rating is withdrawn, and the table cannot tell me which.

The per-producer query shows that activity is uneven. Movie 6 has 21 ratings and movie 4 has 6. I set the threshold for a reliable rate at 10 ratings. The platform has about 15 ratings per movie, and below 10 a single rating moves a rate by 10 points or more. A threshold of 10 keeps 12 of the 13 movies and drops only movie 4.

For the two-dimension query I grouped by region and rating status. The data has no region column, so I used `device_country`, the country a rating was submitted from. Grouping this way gives 14 rows instead of 15, because India has no flagged ratings and a combination with no rows does not appear in the output.

### Who acts on this, and what the aggregate hides

The person who would act on the per-producer breakdown is the trust and safety lead, who decides which movies get a manual review of their incoming ratings. The trust and safety lead needs to know where to spend limited reviewing time.

An average hides its distribution. The platform average of 2.85 hides how the scores are spread. Of the 200 scores, 34 sit at 0.5 and 35 sit at 5.0, so more than a third of all ratings are at one of the two ends. Only 95 of the 200 scores fall on a half star step, even though my Unit 2 design set the scale at half stars. The average of a movie can look middling because ratings at both ends cancel out, and it can look low because of the withdrawn ratings at 0.5.

A count hides who is counted. The per-movie counts cover 13 movies, but the table holds 15, so movies 14 and 15 have never been rated and drop out of every grouped result without any sign that they were left out. A rating count is also a count of events and not of people. Movie 1 has 11 ratings from 9 users, and 39 user and movie pairs on the platform have rated more than once.

Next I would need to see the score distribution inside each movie, and not only its average. I would also want the spam withdrawals broken down by the user who submitted them, since users 1 and 21 each have two. The original score a user gave before a rating was withdrawn would help too, because that would show whether the 0.5 values replaced real scores or whether the withdrawal process writes them.

## Task 4.2: Build the breakdown leadership asked for

### Part A: Two numbers in one pass

The conditional aggregation answers two questions side by side. The first is how many ratings each movie received. The second is how many of those ratings were spam withdrawals. Both come from one scan with no WHERE clause, so the denominator is always every rating for that movie. Movies 2 (3 of 16) and 3 (2 of 13) are the outliers. Movie 4 has 1 of 6, which looks high but rests on too few ratings.

### Part B: Subtotals and a grand total

The reader who needs subtotals instead of detail rows is the regional director. A director cares about the region as a whole and has no use for the status rows underneath. In the output, the five rows labelled Region subtotal (Brazil, India, UK, US and Vietnam) are the subtotals, and the row labelled All regions with the type Grand total is the grand total. The `GROUPING()` function produces those labels, and the HAVING clause removes the detail rows. The five subtotals add up to the grand total of 200 ratings and 12 spam withdrawals.

The grand total supports a decision that the region rows cannot. It gives the platform-wide spam rate of 6.0 percent, which is the figure a payout or freeze decision depends on. A region row can only say that India sits at 10.0 percent. Without the platform figure next to it, there is no way to tell whether 10.0 percent is high or ordinary.

### Part C: A two-step pipeline

The pipeline answers this question. Among movies with enough ratings to judge, what spam rate is normal, and which movies sit above it? The first step summarizes every movie, and the second step aggregates that summary over the 12 movies with at least 10 ratings. Combining all 194 ratings gives a baseline of 5.67 percent, and the average of the 12 movie rates is 6.07 percent. I used the combined figure for the comparison because it weighs each rating equally, so a movie with 21 ratings counts for more than a movie with 11. A second query then lists the high-volume movies above that baseline, and movies 2 and 3 are the only two far above it.

## Reflection

Conditional aggregation computes several answers during one pass over the data. Two separate filtered queries each read the table from the beginning, so the work doubles. At 200 rows nobody notices, but at a million rows each pass means reading every row, and the second query waits for the first or competes with it for the same data. Adding a third and fourth measure with separate queries multiplies that cost, while another CASE column in the single query adds almost nothing.

The difference matters for correctness as well as speed. A filtered query cannot produce its own denominator. If I count spam withdrawals with a WHERE clause, the rows that are not spam are gone, so the total has to come from a second query. The Unit 3 dashboard went wrong in this way, because its filter changed which rows the total was measured over. In a single pass, both numbers come from the same rows by construction.

Two queries can also disagree if the table changes between them. With a million rows and continuous writes, the second scan may see new ratings that the first did not, and the rate then divides numbers from two different moments. The single query reads one consistent snapshot, which makes the result easier to trust.
