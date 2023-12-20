# Decreasing Returns to Scale (DRS) Analysis

This repository researches and analyzes Decreasing Returns to Scale (DRS) in Portfolio Management. It focuses on implementing and exploring methodologies from significant studies to understand the impact of DRS on risk-adjusted returns and fund size. The core of this repository is the R script `IdStartegyDRS.R`, which handles data processing, analysis, and econometric modeling.

## Repository Structure

- **/scripts**: Contains the `IdStrategyDRS.R` script for DRS analysis.
- **/results**: Stores outputs from the script, including tables and figures.
- **/docs**: Provides additional documentation related to the project.

## Methodology

`IdStrategyDRS.R` employs a rigorous econometric approach informed by methodologies from key studies in the field:

### Influential Studies

1. **Chen et al. (2004)**: Investigated the relationship between fund size and risk-adjusted returns, suggesting a DRS effect.
2. **Pástor et al. (2015)**: Critiqued earlier approaches for biases and introduced an advanced demeaned estimator.
3. **Zhu (2018)**: Improved the demeaned estimator technique (RD2), addressing limitations in previous studies.

### Script Approach

- **Data Preprocessing**: Adjusts for inflation and risk-adjusted returns, aligning with financial data analysis best practices.
- **Two-Stage Regression Analysis**:
  - **First Stage**: Applies a demeaning process on fund size variables to reduce positive bias, per Zhu (2018) RD2 methodology.
  - **Second Stage**: Conducts regression analysis with demeaned variables to accurately capture the DRS effect.

## Literature Review

The exploration of DRS in portfolio management is a significant research area in finance, with numerous studies contributing to our understanding.

### Key Studies

1. **[Chen et al. (2004)](https://www.aeaweb.org/articles?id=10.1257/0002828043052277)**: Pioneered the investigation into the relationship between fund size and risk-adjusted returns, highlighting the DRS effect.
2. **[Pástor et al. (2015)](http://www.sciencedirect.com/science/article/pii/S0304405X14002542)**: Identified biases in earlier studies and proposed a demeaned estimator for a more accurate depiction of the DRS phenomenon.
3. **[Zhu (2018)](https://www.sciencedirect.com/science/article/pii/S0304405X18301508)**: Enhanced the demeaned estimator technique, adding flexibility and addressing previous methodological constraints.

## Pre-Processing Data

### Adjusting Total Net Assets (TNA) by Inflation

- **TNA Adjustment**: Adjusts TNA for inflation to acknowledge the time-varying nature of the investment opportunity set and its impact on large funds' performance.
- **Passive Funds Handling**: Differentiates between passive and active funds for more accurate analysis.

$$
MP_{current}=\frac{\sum_{stock} OutShares_{stock, benchperiod} \times Price_{stok, bench period}}{\sum_{stock} OutShares_{stock, current} \times Price_{stok, current}}

$$
ATNA=TNA_{t} \times MP_{t}, \; FundSize_{t}=log(ATNA_{t})
$$

Alternatively, instead of adjusting TNA by Market Capitalization, you can use inflation prices, following the MP file.


### Final steps Before Regressions


- Chen et al. (2004): Focused on domestic equity funds, specifically growth, growth and income, and aggressive growth funds. They excluded sector and international funds and did not adjust TNA for inflation. Their methodology required at least one year of return data to estimate risk-adjusted returns alpha, utilizing CAPM, Fama-French three-factor, and Carhart models.

- Pástor et al. (2015): Used data similar to Chen et al. but excluded passive funds. They adjusted TNA by inflation at 2011 prices and implemented additional requirements like ATNA > 15 and Age > 2 to avoid incubation bias. Once a fund met these size requirements, its data were retained even if the size later dropped below these thresholds.

- Zhu (2018): Continued with the same data as Pástor et al. and followed similar methodologies, including adjusting TNA by inflation at 2011 prices.



### Identification Strategy

This section outlines the identification strategy used in the repository, focusing on three key econometric models:

1. **Model 1: Fama-Macbeth (Chen et al., 2004)**
   - Method: Utilizes independent OLS cross-section regressions for each period to analyze the distribution of estimators.
   - Bias: $\beta_{OLS}= \beta + positiveBias$, favoring Increasing Returns to Scale (IRS).
   - Controls: Includes variables like Family Size (log(Fam-TNA)), Turnover, Age, Expenses, Total Loads, Flows.

2. **Model 2: DR1 Recursive Forward Demean Estimator (Pástor et al., 2015)**
   - Approach: Implements a demeaning process on fund size variables and conducts a Two-Stage Least Squared regression analysis.
   - First Stage:
     - Uses backward-demeaned estimators as instruments for forward-demeaned variables.
     - Addresses potential biases by removing contemporaneous correlation.
     - Avoids the inclusion of an intercept to reduce R-squared and potential Type II errors.
   - Second Stage:
     - Conducts OLS regression without an intercept, focusing on the recursive demeaned form.
     - Uses robust standard errors for improved precision.
   - Bias: $\beta_{FE}=\beta +NegativeBias$, favoring Decreasing Returns to Scale (DRS).
   - Equation: 
     $$
     \bar{R_{i,t}^{F}}=\beta \bar{X_{i,t-1}^{F}} +\bar{\epsilon_{i,t}^{F}}
     $$
     $$
     \bar{R_{i,t}^{F}}= R_{i,t}-\frac{1}{T_{i}-t+1} \sum_{s=t}^{T_{i}} R_{i,s}, \bar{X_{i,t}^{F}}= X_{i,t}-\frac{1}{T_{i}-t+1} \sum_{s=t}^{T_{i}} X_{i,s}
     $$
     $$
     \bar{X_{i,t-1}^{F}}=\rho \bar{X_{i,t-1}^{B}}+\upsilon_{i,t-1}
     $$

3. **Model 3: DR2 (Zhu, 2018)**
   - Improvement: Zhu's model adds an intercept in the first stage, providing a less restrictive approach than DR1.
   - Focus: Emphasizes robust standard errors and the inclusion of controls and fixed effects in the analysis.
   - Equation:
     $$
     \bar{X_{i,t-1}^{F}}=\psi+\rho X_{i,t-1}+\upsilon_{i,t-1}
     $$
     $$
     \bar{R_{i,t}^{F}}=\beta_{RD2} \hat{X_{i,t-1}^{F}}+U_{i,t}
     $$

This comprehensive approach to identification strategy enables a nuanced analysis of the DRS effect in portfolio management, drawing on advanced econometric techniques and insights from pivotal studies in the field.

