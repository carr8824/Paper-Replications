# Load required libraries
library(readr)
library(haven)
library(dplyr)
library(labelled)
library(sjlabelled)
library(lubridate)
library(DescTools)
library(RcppRoll)
library(stringr)

# --------------------------------------------------
# ------------------------------
# Benchmark-Adjusted Returns Calculation
# ------------------------------
# Calculates the returns for stocks traded in financial markets
# Adjusts for break-points: Size x Value x Momentum (Risk Characteristics)
# Based on Daniel, Grinblatt, Titman, Wermers (1997): Measuring Mutual Fund Performance with Characteristics-Based Benchmarks
# --------------------------------------------------

# Importing stock level data from two sources
# A) Quarterly Compustat Data (e.g., assets: atq, liabilities: ltq)
CRSPFundamentalsQ <- read_dta("CRSPFundamentalsQ.dta")
# mkvaltq : This variable is directly reported by CRSP-Compustat (denote Equity-Market Value). Alternative you can calculated by Shares-Outstanding x Price
# bmrq : I calculate the variable using (atq-ltq)/mkvaltq
# B) Monthly CRSP Prices Data (e.g., Price at month-end: PRC, average monthly trading volume: Vol)
MonthlyCRSPStock <- read_dta("MonthlyCRSPStock.dta")
# This data bring information on prices
# Note: Compustat provides quarter-end prices, but market data is directly sourced from CRSP for accuracy
# The script standardizes report information to the last month of each quarter (March, June, September, December)

# Preprocessing Monthly CRSP Data to create momentum variables
# Calculating monthly returns and cumulative quarterly returns
MonthlyCRSPStock <- MonthlyCRSPStock %>%
  arrange(PERMNO, caldt) %>%
  group_by(PERMNO) %>%
  mutate(LPRC = lag(PRC, 1), # PRC are prices 
         MRet = (PRC - LPRC) / PRC, 
         MRet = ifelse(is.infinite(MRet), NA, MRet), 
         GR = 1 + MRet, # previous step before compounding
         GR1 = ifelse(is.na(GR), 1, GR), # deal with missing information before compounding
         Quarter = quarter(caldt), 
         Year = year(caldt)) %>%
  group_by(Year, Quarter, PERMNO) %>% # define subsets of data fro compounding
  mutate(CGR = cumprod(GR1), 
         CGR1 = ifelse(CGR == 1, NA, CGR),  # no compoundings is a missing set of data
         pqret = CGR1 - 1, # come back to quarterly returns
         QRet = ifelse(length(sum(!is.na(pqret))) > 0, 
                       tail(pqret[which(!is.na(pqret))], 1),
                       NA)) %>% # Keep the compounded information at quarter-end or at the last avaibale date within quarter
  ungroup() %>%
  mutate(Month = month(caldt)) %>%
  filter(Month %in% c(3, 6, 9, 12)) %>%
  select(caldt, PERMNO, PERMCO, TICKER, CUSIP, NCUSIP, COMNAM, SICCD, EXCHCD, SHRCD, PRC, QRet) %>%
  distinct()

# Pre.processing Quarterly Compustat Data
# Adjusting for reporting dates and standardizing to the last month of the quarter
CRSPFundamentalsQ <- CRSPFundamentalsQ %>%
  arrange(PERMNO, caldt) %>%
  mutate(Quarter = quarter(caldt), 
         Year = year(caldt)) %>%
  group_by(Year, Quarter, PERMNO) %>%
  mutate(qdate = ifelse(length(sum(!is.na(caldt))) > 0,
                        tail(caldt[which(!is.na(caldt))], 1),
                        NA)) %>% # Confirming the last month within a quarter a stcok reported information
  ungroup() %>%
  filter(caldt == qdate) %>% # Keep only one report within a quarter for a stock : The last
  mutate(qdate = case_when(Quarter == 1 ~ paste(Year, "03", "28", sep = "-"),
                           Quarter == 2 ~ paste(Year, "06", "28", sep = "-"),
                           Quarter == 3 ~ paste(Year, "09", "28", sep = "-"),
                           Quarter == 4 ~ paste(Year, "12", "28", sep = "-")),
         caldt = as.Date(qdate)) %>% # adjusting the date into the last month of the quarter to mantain structure of the data
  select(-c(Quarter, Year, qdate))

# Merging Quarterly Compustat Data with Monthly CRSP Data
# Leveraging missing information in CRSP with fundamentals
DataStock <- full_join(MonthlyCRSPStock, CRSPFundamentalsQ, by = c("PERMNO", "caldt")) %>%
  mutate(PERMCO = ifelse(is.na(PERMCO), LPERMCO, PERMCO),
         TICKER = ifelse(is.na(TICKER), LTICKER, TICKER),
         CUSIP = ifelse(is.na(CUSIP), LCUSIP, CUSIP),
         COMNAM = ifelse(is.na(COMNAM), conm, COMNAM),
         PRC = ifelse(is.na(PRC), prccq, PRC)) %>%
  select(caldt, PERMNO, PERMCO, TICKER, CUSIP, NCUSIP, COMNAM, SICCD, EXCHCD, SHRCD, PRC, QRet, mkvaltq, bmrq) %>%
  distinct()

# Prepare Quarterly Stock Data for Portfolio Analysis
QuarterlyCRSPStock <- DataStock


# --------------------------------------------------
# Calculating Stock Momentum Based on Last Four Quarters
# --------------------------------------------------
# Momentum is calculated as the product of gross quarterly returns (GQRet) over the last four quarters.
# This method is used to assess the stock performance trend over a year.

# Enhancing Quarterly Stock Data with Gross Quarterly Return (GQRet)
# GQRet is calculated as (1 + Quarterly Return) and adjusted for missing data
# Then, the Cumulative Gross Quarterly Return (CGQRet) is computed using a rolling product over the last four quarters
QuarterlyCRSPStock <- QuarterlyCRSPStock %>%
  mutate(GQRet = ifelse(is.na(QRet), 1, 1 + QRet)) %>%
  group_by(PERMNO) %>%
  mutate(CGQRet = roll_prod(GQRet, n = 4, align = "right", fill = NA),
         CGQRet = ifelse(CGQRet == 1, NA, CGQRet),  # Adjusting for cases where CGQRet is default 1
         MomRet = CGQRet - 1) %>%  # Calculating Momentum Return
  ungroup() %>%
  select(-GQRet, -CGQRet)  # Removing intermediate variables

# The resulting 'MomRet' column represents the stock momentum based on the last year's performance

# --------------------------------------------------
# Reading and Processing K R French Breakpoints for Portfolio Classification
# --------------------------------------------------
# These breakpoints are used to classify stocks into portfolios based on different financial metrics.

# Reading Book to Market Ratio (BE/ME) Breakpoints - Annual Frequency
# Each 5th percentile is provided for NYSE Market Equity (ME)
BE_ME_Breakpoints <- read_delim("BE-ME_Breakpoints.csv", delim = ";") 

# Reading Market Equity (ME) Breakpoints - Monthly Frequency
# Contains every 5th NYSE ME percentile, divided by 1,000,000
ME_Breakpoints <- read_delim("ME_Breakpoints.csv", delim = ";") 

# Reading Momentum (MOM) Breakpoints - Monthly Frequency
# Information provided as a percentage
MOM_Breakpoints <- read_delim("MOM_Breakpoints(2_12).csv", delim = ";") 

# Adjusting dates to work with R and filtering data for the relevant period (2000-2020)
ME_Breakpoints <- ME_Breakpoints %>%
  mutate(caldt = ymd(paste0(YearMonth, "28"))) %>%
  filter(caldt > "1999-12-28" & caldt < "2021-01-28")

MOM_Breakpoints <- MOM_Breakpoints %>%
  mutate(caldt = ymd(paste0(YearMonth, "28")),
         # Converting percentiles to decimals for consistent calculation
         P20 = P20 / 100, P40 = P40 / 100, P60 = P60 / 100, P80 = P80 / 100, P100 = P100 / 100) %>%
  filter(caldt > "1999-12-28" & caldt < "2021-01-28")

BE_ME_Breakpoints <- BE_ME_Breakpoints %>%
  select(Year, P20, P40, P60, P80, P100) %>%
  filter(Year > 1999 & Year < 2021)

# --------------------------------------------------
# Adjusting Outliers in Quarterly Stock Data
# --------------------------------------------------
# Applying Winsorization to mitigate the impact of extreme values in key financial metrics.

QuarterlyCRSPStock <- QuarterlyCRSPStock %>%
  mutate(Year = year(caldt)) %>%
  group_by(caldt) %>%
  # Winsorizing key financial metrics to constrain them within the 5th and 95th percentiles
  mutate(bmrq = Winsorize(bmrq, probs = c(0.05, 0.95), na.rm = TRUE),
         mkvaltq = Winsorize(mkvaltq, probs = c(0.05, 0.95), na.rm = TRUE),
         MomRet = Winsorize(MomRet, probs = c(0.05, 0.95), na.rm = TRUE)) %>%
  ungroup()

# --------------------------------------------------
# Constructing the First Sorting of Portfolios Based on Market Equity (ME)
# --------------------------------------------------
# This process classifies stocks into one of five segments (quintiles) based on ME breakpoints.

# Define the total number of portfolios and intervals for segmentation
NP <- 125  # The total number of portfolios desired
int <- c(seq(1, NP, NP/5), NP+1)  # Labels for the first segment

# Merging Quarterly Stock Data with ME Breakpoints
Data <- left_join(QuarterlyCRSPStock, ME_Breakpoints, by = "caldt")

# Filtering data for the analysis period (up to the year 2020)
Data <- Data %>% filter(Year < 2021)

# Classifying each stock into one of the five ME-based segments
Data <- Data %>%
  mutate(NPort5 = case_when(
    is.na(mkvaltq) ~ NA_real_,
    mkvaltq <= P20 ~ int[1],  # First Port
    mkvaltq > P20 & mkvaltq <= P40 ~ int[2],  # Second Port
    mkvaltq > P40 & mkvaltq <= P60 ~ int[3],  # Third Port
    mkvaltq > P60 & mkvaltq <= P80 ~ int[4],  # Fourth Port
    mkvaltq > P80 ~ int[5]  # Fifth quintile
  ))

# Removing the ME breakpoints columns after classification
Data <- select(Data, -c(P20, P40, P60, P80, P100))


# --------------------------------------------------
# Second Sorting of Portfolios Based on ME and BE/ME
# --------------------------------------------------
# Stocks are further classified into 25 portfolios based on their ME quintile and BE/ME ratio.

# Merging the initial Data with BE/ME Breakpoints
Data=left_join(Data, BE_ME_Breakpoints)
# Classifying each stock into one of 25 portfolios based on their ME quintile and BE/ME ratio
# We start classification
Data=Data%>%group_by(caldt, NPort5)%>%
  mutate(NPort25=ifelse(is.na(NPort5), NA, 
                        ifelse(NPort5==1,
                               # First group of previous sorting
                               ifelse(is.na(bmrq), NA, 
                                      ifelse(bmrq<=P20, seq(int[1],int[2]-1,5)[1],
                                             ifelse(bmrq > P20 & bmrq<= P40, seq(int[1],int[2]-1,5)[2],
                                                    ifelse(bmrq>P40 & bmrq <= P60, seq(int[1],int[2]-1,5)[3], 
                                                           ifelse(bmrq > P60 & bmrq <= P80, seq(int[1],int[2]-1,5)[4],
                                                                  ifelse(bmrq > P80, seq(int[1],int[2]-1,5)[5], NA)))))),
                               ifelse(NPort5==26,
                                      # Second group of previous Sorting
                                      ifelse(is.na(bmrq), NA, 
                                             ifelse(bmrq<=P20, seq(int[2],int[3]-1,5)[1],
                                                    ifelse(bmrq > P20 & bmrq<= P40, seq(int[2],int[3]-1,5)[2],
                                                           ifelse(bmrq>P40 & bmrq <= P60, seq(int[2],int[3]-1,5)[3], 
                                                                  ifelse(bmrq > P60 & bmrq <= P80, seq(int[2],int[3]-1,5)[4],
                                                                         ifelse(bmrq > P80, seq(int[2],int[3]-1,5)[5], NA)))))),
                                      ifelse(NPort5==51,
                                             # Third group of previous Sorting
                                             ifelse(is.na(bmrq), NA, 
                                                    ifelse(bmrq<=P20, eq(int[3],int[4]-1,5)[1],
                                                           ifelse(bmrq > P20 & bmrq<= P40, seq(int[3],int[4]-1,5)[2],
                                                                  ifelse(bmrq>P40 & bmrq <= P60, seq(int[3],int[4]-1,5)[3], 
                                                                         ifelse(bmrq > P60 & bmrq <= P80, seq(int[3],int[4]-1,5)[4],
                                                                                ifelse(bmrq > P80, seq(int[3],int[4]-1,5)[5], NA)))))),
                                             ifelse(NPort5==76,
                                                    # Fourth group of previous Sorting
                                                    ifelse(is.na(bmrq), NA, 
                                                           ifelse(bmrq<=P20, seq(int[4],int[5]-1,5)[1],
                                                                  ifelse(bmrq > P20 & bmrq<= P40, seq(int[4],int[5]-1,5)[2],
                                                                         ifelse(bmrq>P40 & bmrq <= P60, seq(int[4],int[5]-1,5)[3], 
                                                                                ifelse(bmrq > P60 & bmrq <= P80, seq(int[4],int[5]-1,5)[4],
                                                                                       ifelse(bmrq > P80, seq(int[4],int[5]-1,5)[5], NA)))))),
                                                    # ELSE: Fifth group of previous Sorting
                                                    ifelse(is.na(bmrq), NA, 
                                                           ifelse(bmrq<=P20, seq(int[5],int[6]-1,5)[1],
                                                                  ifelse(bmrq > P20 & bmrq<= P40, seq(int[5],int[6]-1,5)[2],
                                                                         ifelse(bmrq>P40 & bmrq <= P60, seq(int[5],int[6]-1,5)[3], 
                                                                                ifelse(bmrq > P60 & bmrq <= P80, seq(int[5],int[6]-1,5)[4],
                                                                                       ifelse(bmrq > P80, seq(int[5],int[6]-1,5)[5], NA))))))
                                                    
                                                    
                                             ) 
                                      )
                               )
                        )
  )
  )%>%
  ungroup()


# Removing the BE/ME breakpoints columns after classification
Data <- select(Data, -c(P20, P40, P60, P80, P100))
# --------------------------------------------------
# Final Sorting of Portfolios Based on ME, BE/ME, and Momentum (MOM)
# --------------------------------------------------
# This step classifies stocks into 125 portfolios based on ME, BE/ME, and MOM criteria.

# Merging Data with Momentum (MOM) Breakpoints
Data <- left_join(Data, MOM_Breakpoints, by = "caldt")

# Classifying each stock into one of 125 portfolios based on ME, BE/ME, and MOM
Data <- Data %>%rowwise()%>%
  mutate(
    # Manejar NA en MomRet y luego usar findInterval
    MomRet_cat = ifelse(
      is.na(MomRet),
      NA,
      findInterval(MomRet, c(P20, P40, P60, P80), rightmost.closed = TRUE)
    ))%>%ungroup()%>%
  mutate(
    # Crear NPort125 combinando NPort25 con la clasificación de MomRet
    NPort125 =  NPort25 + MomRet_cat )

# Removing MOM breakpoints columns after classification
Data <- select(Data, -c(MomRet_cat, P20, P40, P60, P80, P100))


# --------------------------------------------------
# Calculating Benchmark Adjusted Returns for Portfolios
# --------------------------------------------------
# This section calculates both Equally Weighted and Value-Weighted Benchmark Adjusted Returns for each portfolio.

# Calculating Equally Weighted Benchmark Adjusted Returns (EWBAR)
Data <- Data %>%
  group_by(caldt, NPort125) %>%
  mutate(EWBAR = ifelse(is.na(NPort125), NA, mean(QRet, na.rm = TRUE))) %>%
  ungroup()

# Calculating Value-Weighted Returns (VWBAR) using market size as weights
Data <- Data %>%
  group_by(caldt, NPort125) %>%
  mutate(
    Weights = mkvaltq / sum(mkvaltq, na.rm = TRUE),
    Weights = ifelse(is.infinite(Weights) | is.na(QRet), NA, Weights),
    NWeights = Weights / sum(Weights, na.rm = TRUE),
    VWBAR = ifelse(is.na(NPort125), NA, sum(NWeights * QRet, na.rm = TRUE))
  ) %>%
  ungroup() %>%
  select(-c(mkvaltq, bmrq, Weights, NWeights))

# Final Data Preparation for Export
Data <- Data %>%
  select(-c(MomRet, Year, NPort5, NPort25, NPort125)) %>%
  distinct()

# Setting variable labels for clarity in the exported dataset
QuarterlyCRSPBAR <- set_variable_labels(Data, .labels = c(
  "Current Date", "Permanent Number ID : CRSP",
  "Permanent Company Code: Compustat", "Ticker",
  "Cusip", "Ncusip", "Company Name", "Standard Industry Classification Code",
  "Exchange Code", "Share Class Code", "Closing Price : Quarter-End",
  "Monthly Compound within Quarter: Buy and Hold Assumption",
  "Equally Weighted Return Portfolio: 125 Portfolio",
  "Value Weighted Return Portfolio: 125 Portfolio / Weights on Market Equity"
))

# Exporting the processed data: QuarterlyCRSPBAR
