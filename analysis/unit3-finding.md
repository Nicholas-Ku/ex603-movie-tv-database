# Unit 3 Finding: The Spam Withdrawal Rate

**To:** The dashboard team
**From:** Nicholas Ku, Trust and Data

The dashboard said about half of all ratings end up withdrawn as spam, and leadership froze the quarterly reviewer payout because of it. I went back through all 200 ratings, and only 12 of them were withdrawn as spam, which comes to 6 percent.

The mistake was in which ratings the calculation counted. A rating only gets a withdrawal reason when it's withdrawn, so 166 of the 200 ratings have no reason at all. The calculation filtered on the reason, and any rating with a blank reason quietly dropped out of the total. With most of the ratings gone, the 12 spam withdrawals were measured against a much smaller group than the real 200, which made the rate look far bigger than it is. The result looked reasonable and nothing reported an error, so no one had a reason to double check it until someone who knows the platform noticed it didn't match what they see.

I'd release the frozen payout once someone confirms that a 6 percent spam rate doesn't trigger the freeze rule, since I wasn't given the cutoff. The dashboard calculation also needs to count every rating, and I'm happy to hand the team a corrected version. Ten ratings are flagged and still under review. I left them out because they aren't withdrawals yet, but even if all ten ended up as spam, the rate would be 11 percent, which is still nowhere near half.
