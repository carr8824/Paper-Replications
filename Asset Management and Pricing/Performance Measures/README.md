# Performance Measures

## Overview

This section explores various ways to define performance in mutual funds, focusing on the standard and most commonly used methods in the literature. Performance is often gauged through returns, which can be net returns (after fees and costs) or gross returns. The complexity of these measures requires a solid understanding of mathematics and statistics to derive meaningful conclusions.

## Ex-Post Measures

Ex-post measures refer to performance already realized, incorporating the cumulative decisions of managers. While these measures effectively reflect the overall portfolio's performance, they may not fully capture the skill or added value of managers.

### Alpha Risk-Adjusted (\(\alpha\))

- **Background**: The finance literature includes models like CAPM ([Sharpe, (1964)](https://onlinelibrary.wiley.com/doi/full/10.1111/j.1540-6261.1964.tb02865.x); .[Lintner, (1975)](https://www.sciencedirect.com/science/article/pii/B9780127808505500186)) and the three-factor model (.[Fama and French, (1993)](http://www.sciencedirect.com/science/article/pii/0304405X93900235)), which explain prices through risk factors. The concept extends to asset management, where portfolios are evaluated based on risk-adjusted performance.

- **Model Variations**: .[Carhart, 1997](https://onlinelibrary.wiley.com/doi/abs/10.1111/j.1540-6261.1997.tb03808.x) introduced the momentum factor (WML), while .[ Pastor and Stambaugh, 2003](https://www.journals.uchicago.edu/doi/abs/10.1086/374184) incorporated a liquidity risk factor. These models, however, are primarily applicable to equity portfolios.

- **Standard Application**:
  - The standard application involves OLS regressions to derive the intercept as the return from the portfolio not explained by risk factors:
    \[
    R-R_{f}=\alpha + \sum_{j} B^{j} Risk^{j}+\epsilon
    \]
  - An alternative approach in mutual funds compares the realized return with the expected return:
    \[
    R_{t+1}-\alpha-\sum_{j} B^{j} Risk^{j}
    \]

- **Considerations**: Calculating \(\alpha\) typically requires at least 12 months of data. However, this may introduce bias due to endogeneity and correlation with past variables. Focusing on one-step performance not explained by past factors can mitigate but not eliminate this bias.

This section aims to provide a comprehensive understanding of how mutual fund managers' performance can be assessed using various risk-adjusted measures.

### Return Gap (RGAP)

## Ex-ante Measures

### Characteristic Selectivity

### Trading Selectivity 


