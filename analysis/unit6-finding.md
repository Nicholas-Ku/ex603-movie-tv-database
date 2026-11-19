# Unit 6 Finding: Is the Platform Getting Better or Worse?

**To:** The leadership team
**From:** Nicholas Ku, Trust and Data

The spam problem got a little better over 2023, but the counts are too small to call it solved. The spam withdrawal rate fell every quarter, from 7.5 percent in the first quarter to 6.3, 5.9 and 4.2 percent in the last (6.3B-3 in [q6_3.sql](../queries/unit6/q6_3.sql)). Volume held steady at 48 to 53 ratings a quarter over the same period, so the lower rate is not the result of fewer ratings being counted. The rate over the most recent 30 ratings shows the same pattern. The 30-rating rate peaked at 10 percent between May and September, sat at 0 from mid October to mid December, and ended the year at 6.7 percent (6.2B-3 in [q6_2.sql](../queries/unit6/q6_2.sql)).

I would still be careful with the trend, because the fourth quarter had only 2 spam withdrawals, and one more would have put the fourth quarter level with the second. The monthly numbers can't settle the question either. With 0 to 2 spam withdrawals a month, the monthly rate moved by as much as 18 points from one month to the next, on just 2 spam withdrawals in March (6.3B-2).

The bigger problem for next quarter is how many ratings come in at all. The platform collected 200 ratings in 2023, 40 short of a target of 240, or 20 a month (6.2B-2). Most of that shortfall came in March and April, which had only 11 ratings each. In those same weeks, movies 5, 9, 11 and 12 all went about three months without a rating, while 11 or 12 other movies kept being rated (6.2C-1 and 6.2C-2). The platform kept recording ratings, so I don't think data was lost. I can't tell from the table whether those four movies were hidden or unavailable for part of that time, because the table only stores whether a movie is available today. Movies 14 and 15 have still never been rated (6.1B in [q6_1.sql](../queries/unit6/q6_1.sql)).

For next quarter, I recommend three things.

1. Keep moderation at its current level and change how spam is reported. Leadership should see the quarterly rate, with the spam count beside it, and the trust and safety lead should review a month only when it has at least 3 spam withdrawals or the 30-rating rate goes above 10 percent (6.2B-4 and 6.3B-3). A monthly alert on the rate alone would fire on a single rating.
2. Ask the catalog team for the availability history of movies 5, 9, 11 and 12 in March and April, and whether movies 14 and 15 show up on the site and in search. A request to the catalog team is the cheapest way to learn whether the spring slowdown came from users or from the catalog (6.2C-2).
3. Find out where the 0.5 score on withdrawn ratings comes from before anyone uses average scores to judge a movie. Of the 25 ratings that sit more than 2 points below their movie's average, 20 are withdrawals with that score (6.1A-4), and 28 of the 67 large rating-to-rating swings involve one (6.2A-2).

What I can't tell from the data is whether the falling spam rate will hold with more ratings, why four movies went quiet in the same weeks, and whether users really gave a score of 0.5 to the ratings that were later withdrawn.
