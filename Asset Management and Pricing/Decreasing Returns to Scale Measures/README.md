# Decreasing Returns to Scale (DRS) Analysis

This repository contains research and analysis on Decreasing Returns to Scale (DRS) in Portfolio Management. It focuses on implementing and exploring methodologies developed in critical studies to understand the DRS effect on risk-adjusted returns and fund size. The central piece of this repository is the R script `IdStartegyDRS.R`, which encapsulates the data processing, analysis, and econometric modeling.

## Repository Structure

- `/scripts`: Includes the R script `IdStartegyDRS.R` for analysis.
- `/results`: Stores output from the scripts, like tables and figures.
- `/docs`: Additional documentation related to the project.

## Methodology

The script `IdStartegyDRS.R` follows a rigorous econometric approach, building upon methodologies from pivotal studies in the field:

### Key Studies Influencing the Methodology:

- **Chen et al. (2004)**: Explored the relationship between fund size and risk-adjusted returns, suggesting a DRS effect.
- **Pástor et al. (2015)**: Critiqued earlier approaches for biases and proposed an advanced demeaned estimator.
- **Zhu (2018)**: Improved the demeaned estimator technique (RD2), addressing methodological limitations in previous studies.

### Approach in `IdStartegyDRS.R`:

1. **Data Preprocessing**: The script adjusts for inflation and risk-adjusted returns, aligning with best practices in financial data analysis.
   
2. **Two-Stage Regression Analysis**:
   - **First Stage**: Implements a demeaning process on fund size variables to mitigate positive bias, following Zhu (2018) RD2 methodology.
   - **Second Stage**: Performs regression analysis using the demeaned variables to capture the DRS effect accurately.



## Literature Review

The exploration of Decreasing Returns to Scale (DRS) in portfolio management has been a critical area of research in finance, with several vital studies contributing significantly to our understanding.

### [Chen et al. (2004)](https://www.aeaweb.org/articles?id=10.1257/0002828043052277)

The journey into understanding DRS in fund performance began with Chen et al. (2004), who were pioneers in investigating the relationship between fund size and risk-adjusted returns. Their study was groundbreaking in highlighting the DRS effect, suggesting that larger funds might not always yield better returns. This finding was crucial as it challenged the conventional wisdom that bigger funds, typically associated with more resources and potentially better management, would automatically lead to superior performance.

### [Pástor et al. (2015)](http://www.sciencedirect.com/science/article/pii/S0304405X14002542)

Building on the work of Chen et al., Pástor et al. (2015) brought a new perspective by scrutinizing the identification strategy of the earlier study. They identified a positive bias in the methodology of Chen et al., meaning that the approach intended to find a DRS effect could erroneously indicate Increasing Returns to Scale (IRS). Pástor et al. proposed a demeaned estimator capable of controlling for fund-fixed effects without incurring a negative bias to address this issue. This development was significant as it aimed to provide a more accurate depiction of the DRS phenomenon. However, this demeaned estimator, known as RD1, was not without its limitations. It imposed certain restrictions without clear theoretical or practical justifications, potentially constraining its applicability.

###  [Zhu (2018)](https://www.sciencedirect.com/science/article/pii/S0304405X18301508)

Zhu (2018) further refined the approach to studying DRS in portfolio management by enhancing the demeaned estimator technique introduced by Pástor et al. Zhu's contribution was vital in adding flexibility to the RD1 model, addressing the previous model's rigid and, at times, theoretically unsupported restrictions. This enhanced demeaned estimator, termed RD2, marked a significant step forward in accurately quantifying the DRS effect on fund performance, providing a more robust and flexible tool for researchers and practitioners in finance.



## Pre-Processing Data

### Adjusting Total Net Assets (TNA) by Inflation

Adjusting TNA for inflation is a crucial step in portfolio management research, as it acknowledges the time-varying nature of the investment opportunity set. The size of the market can significantly impact the performance of large funds. For instance, a large fund in a small market might not perform as well as the same fund in a larger market. Fund managers often prioritize their investment choices, allocating to the best ideas first and then moving to the following best as the fund grows, subject to diversification requirements.

$$
MP_{current}=\frac{\sum_{stock} NOutstandShares_{stock, benchmarkperiod} \times Price_{stok, benchmark period}}{\sum_{stock} NOutstandShares_{stock, current} \times Price_{stok, current}},\; \forall \; stock \in CRSP
$$

$$
ATNA=TNA_{t} \times MP_{t}, \; FundSize_{t}=log(ATNA_{t})
$$

### Handling Passive Funds

The approach to passive funds such as index funds (indicated by index_fund_flag) and ETFs (marked by et_flag in ETF and ETN) varies. ETFs can be passive or active; distinguishing between them requires careful consideration.


- Chen et al. (2004): Focused on domestic equity funds, specifically growth, growth and income, and aggressive growth funds. They excluded sector and international funds and did not adjust TNA for inflation. Their methodology required at least one year of return data to estimate risk-adjusted returns alpha, utilizing CAPM, Fama-French three-factor, and Carhart models.

- Pástor et al. (2015): Used data similar to Chen et al. but excluded passive funds. They adjusted TNA by inflation at 2011 prices and implemented additional requirements like ATNA > 15 and Age > 2 to avoid incubation bias. Once a fund met these size requirements, its data were retained even if the size later dropped below these thresholds.

- Zhu (2018): Continued with the same data as Pástor et al. and followed similar methodologies, including the adjustment of TNA by inflation at 2011 prices.



## Identification Strategy

### Model 1: Fama-Macbeth (Chen et al., 2004)

Chen et al. recognized that fund size might attract factors like skilled managers, potentially leading to a positive bias in identifying the relationship between size and future returns. They noted that risk-adjusted returns might exhibit mean reversion while size might not, introducing the possibility of negative bias. To address these issues, they employed the Fama-Macbeth approach, running independent OLS cross-section regressions for each period and then analyzing the distribution of estimators.

$$
R_{i,t}=\lambda + \beta Size_{i,t-1}+ Controls_{i,t-1}+\epsilon_{i,t}
$$

$$
\hat{\beta_{OLS}} = \beta + (Size^{T}Size)^{-1} E[Size \times \epsilon]
$$


$$
\hat{\beta_{OLS}} = \beta + \frac{\sum_{i} \sum_{t} E[Size_{i,t-1} \times \epsilon_{i,t}]}{\sum_{i}\sum_{t} Size_{i,t-1} \times Size_{j,t-1}}
$$

-  $\beta_{OLS}= \beta + positiveBias$ (Favors IRS)

-   Controls: Family Size (log(Fam-TNA)), Turnover, Age, Expenses, Total Loads, Flows.



### Model 2: DR1 Recursive Forward Demean Estimator (Pástor et al., 2015)


-  $\beta_{FE}=\beta +NegativeBias$ (Favors DRS)

Pástor et al. argued against the Fama-Macbeth approach for failing to reduce positive bias and criticized the fixed effects approach for introducing negative bias. They proposed the Recursive Demeaned estimator, which removes the mean without considering future information on Fund Size. This approach was implemented through a Two-Stage Least Squared model, with the first stage using backward-demeaned estimators as instruments for forward-demeaned variables.


$$
\bar{R_{i,t}^{F}}=\beta \bar{X_{i,t-1}^{F}} +\bar{\epsilon_{i,t}^{F}}
$$


$$
\bar{R_{i,t}^{F}}= R_{i,t}-\frac{1}{T_{i}-t+1} \sum_{s=t}^{T_{i}} R_{i,s},\;\; \bar{X_{i,t}^{F}}= X_{i,t}-\frac{1}{T_{i}-t+1} \sum_{s=t}^{T_{i}} X_{i,s}
$$


$$
\bar{X_{i,t}^{B}}= X_{i,t}-\frac{1}{t-1} \sum_{s=1}^{T-1} X_{i,s}
$$

#### First Stage

$$
\bar{X_{i,t-1}^{F}}=\rho \bar{X_{i,t-1}^{B}}+\upsilon_{i,t-1}
$$


-   The fist stage uses the estimated values on $\hat{X_{i,t-1}^{F}}$ using OLS through the previous regression.

-   The estimated values correspond to the information on explanatory variables (FundSize and others) ONLY considering the PAST information. In other words, remove contemporaneous correlation associated with E[$\bar{X_{i,t-1}^{F}} \times \bar{\epsilon_{i,t}^{F}}$] by having an exclusion restriction associated with $E[\bar{X_{i,t-1}^{B}} \times \bar{\epsilon_{i,t-1}^{F}}]$ equal to zero.

-   The regression in the first stage imposes NO INTERCEPT. The restriction does not respond to any functional form. Moreover, imposing the restriction reduces the R-squared in the first stage (reduces the strength of the IV). Mathematically, having NO INTERCEPT implies that the average FundSize using past information is equal to the average FundSize using future information (Not Realistic).

-   The restriction of having NO INTERCEPT increases the chances of having Type-error II (Not reject when is False), over $\hat{\beta_{RD1}}$. In other words, to have non-significant results. Asymptotically, the standard errors are inconsistent due to a lower R-squared in the first stage.

#### Second Stage

$$
\bar{R_{i,t}^{F}}=\beta_{RD1} \hat{X_{i,t-1}^{F}}+U_{i,t}
$$



-   The second stage requires the implementation of an OLS regression. The regression does not include intercept because the recursive demeaned estimator drops any intercept.

-   The inference uses standard errors that are associated with an OLS regression. However, you can use sandwich estimators to improve precision on standard errors.

-   The RECURSIVE DEMEANED form restricts the chances to introduce other fixed effects as their model does not include dummy variables alone. For example, suppose we want to include family or Time x investment style. The literature does not add these effects (why: problematic). Imagine you introduce a dummy by family, then recursively demeaned by family (not eliminate the bias of skill), by both (makes sense to demeaned by fund and family?). In addition, the case for the time x style is more problematic because the recursive process requires a long time series, and in this scenario, you do not have it. Therefore, what the authors do is to be recursively demeaned by funds and then apply time-varying controls.

-   The variable X includes FundSize and other controls associated with a fund—for example, Flows, Expenses, Turnover, etc. The authors argue that you can treat those controls as exogenous variables, meaning that you do not need to demean each control variable as long as you can argue that those controls are not associated with future innovation (like skill) affecting future returns. 


### Model 3: DR2 (Zhu, 2018)

Zhu improved upon Pástor et al.'s methodology by incorporating an intercept in the first stage of their Enhanced Recursive Demeaned estimator, RD2. This approach was less restrictive than the previous model and allowed for a broader application. Zhu emphasized robust standard errors and provided a methodology for incorporating controls and additional fixed effects into the analysis.





$$
\bar{X_{i,t-1}^{F}}=\psi+\rho X_{i,t-1}+\upsilon_{i,t-1}
$$

$$
\bar{R_{i,t}^{F}}=\beta_{RD2} \hat{X_{i,t-1}^{F}}+U_{i,t}
$$


-   The authors signal that at the moment of making an inference, it is required to use robust standard errors. They provide the formula to build sandwich estimators to robust standard errors based on the two-stage least-squared process.


