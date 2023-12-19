# Activism Measures


Managerial activism in mutual funds refers to fund managers' active involvement and decision-making approach in selecting and managing investment portfolios instead of passively following a market index. This concept embodies a fund manager's active engagement in stock selection, market timing, and strategic asset allocation to outperform benchmarks and achieve superior returns. Managerial activism is characterized by a proactive stance in investment decisions, often involving thorough research, analysis of market trends, and taking calculated risks. This approach contrasts with passive management, where a fund's portfolio mirrors a market index, relying on market efficiency rather than active decision-making. Managerial activism in mutual funds can significantly influence fund performance, risk profiles, and investor outcomes, reflecting the manager's expertise, strategies, and market insights in pursuing investment objectives.


## Active Share [Cremers and Petajisto, (2009)](https://doi.org/10.1093/rfs/hhp057)


Active Share is a metric introduced to assess the extent of active management in equity funds. The "Active Share" measure was introduced by K. J. Martijn Cremers and Antti Petajisto in their influential paper, "How Active Is Your Fund Manager? A New Measure That Predicts Performance". The concept is a cornerstone in evaluating active portfolio management. Active Share represents the proportion of fund holdings different from the benchmark index holdings. It's calculated for domestic equity mutual funds. This measure helps understand how much a fund manager deviates from a passive index replication strategy.

###  Calculation of Active Share


<div align="center">
    <img src="img/AF.png" alt="AF = \frac{1}{2} \sum_{i=1}^{N} |w_{fund,i} - w_{index,i}|">
</div>


#### Key Points in the Measure:

- **Division by Two:** This is applied to avoid double-counting positions. Since both the fund's portfolio and a typical passive portfolio (like the S&P 500) sum to 100% in weight, dividing by two ensures no overlap in the calculation.

     - **Evaluating Position Differences:** When both portfolios hold a position in a security, the absolute difference in weights indicates the distance of the fund from the benchmark. This controls whether the fund is underweighting or overweighting a position.

     - **Zero Weight Scenarios:** In cases where the fund has a position not mirrored in the benchmark or vice versa, the activism is captured by the weight present. This method accurately reflects the activism regardless of whether it's due to the fund holding a position that the benchmark doesn't or the reverse.

     - **Complete Divergence Cases:** If the fund's portfolio is entirely different from the benchmark, the comparison is made across all stocks in both portfolios. As the total weights of both portfolios are 100%, without adjusting for overlap, the Active Share could incorrectly sum to 200%. Hence, dividing by two is necessary.

     - **Non-Negativity and Short Positions:** Active Share is always non-negative. Short positions, typically reported in the liabilities section of a balance sheet, are not directly accounted for in the measure. This approach views Active Share as a long-short portfolio metric but focuses on non-perfect replicability due to independent weight optimization in the fund and benchmark.




#### Key Findings

- **Predictive Power:** Active Share is linked with fund performance. Funds with the highest Active Share tend to outperform their benchmarks before and after expenses.
- **Performance Persistence:** Funds exhibiting high Active Share demonstrate strong performance persistence.
- **Underperformance of Low Active Share Funds:** Funds with low Active Share, especially non-index funds, tend to underperform their benchmarks.








## Activism on OverPricing Stocks


## Activism on ESG stocks


## Activism on Illiquidity