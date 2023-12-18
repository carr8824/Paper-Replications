# Load necessary libraries
library(readr)
library(haven)
library(dplyr)
library(labelled)
library(sjlabelled)
library(lubridate)
library(DescTools)
library(RcppRoll)
library(stringr)

# Setting the working directory
# setwd("yourdirectory")

# Define a function to handle sum with NA values
suma <- function(df) {
  if (all(is.na(df))) {
    NA
  } else {    
    sum(df, na.rm = TRUE)
  }
}

# Import Benchmark Adjusted Returns Data from CRSP
QuarterlyCRSPBAR <- read_dta("QuarterlyCRSPBAR.dta")

# Preparing data by calculating forward-looking metrics
# Forward Quarterly Returns, Forward Equally Weighted, and Value-Weighted Benchmark-Adjusted Returns
QuarterlyCRSPBAR <- QuarterlyCRSPBAR %>%
  arrange(PERMNO, caldt) %>%
  group_by(PERMNO) %>%
  mutate(
    FQRet = lead(QRet),         # Forward Quarterly Returns
    FEWBAR = lead(EWBAR125),    # Forward Equally Weighted Benchmark-Adjusted Returns
    FVWBAR = lead(VWBAR125)     # Forward Value-Weighted Benchmark-Adjusted Returns
  ) %>%
  ungroup()

# The data is now prepared for further steps in calculating Characteristic Selectivity

# Function to calculate Characteristic Selectivity
CS <- function(y, QuarterlyStockBAR) {
  # Reading Mutual Fund Holdings Data
  MFHoldings <- read_dta(paste0("MFHoldings_", y, ".dta"))
  
  MFHoldings <- MFHoldings %>%
    arrange(Quarter, ID, TICKER) %>%
    distinct() %>%
    mutate(NCUSIP = CUSIP) %>%
    filter(TICKER != "" & !is.na(TICKER) & NCUSIP != "" & !is.na(NCUSIP)) %>%
    distinct(caldt, ID, TICKER, NCUSIP)  # Removing duplicate holdings
  
  # Prepare for Merging with Quarterly Stock Information
  # Splitting holdings into two datasets for merging: by Ticker and by NCUSIP
  MFT <- MFHoldings %>% filter(TICKER != "" & !is.na(TICKER)) %>% distinct(caldt, ID, TICKER)
  MFNC <- MFHoldings %>% filter(NCUSIP != "" & !is.na(NCUSIP)) %>% distinct(caldt, ID, NCUSIP)
  
  # Merging Mutual Fund Holdings with Quarterly Stock Data
  # First merge by Ticker, then by NCUSIP
  QS1 <- QuarterlyStockBAR %>% select(-NCUSIP, -CUSIP) %>% distinct()
  MFT1 <- inner_join(MFT, QS1, by = c("caldt", "TICKER"))
  
  QS2 <- QuarterlyStockBAR %>% select(-CUSIP, -TICKER) %>% distinct()
  MFNC1 <- inner_join(MFNC, QS2, by = c("caldt", "NCUSIP"))
  
  # Combining Merged Data and Removing Duplicates
  MF <- distinct(rbind(MFT1, MFNC1)) %>%
    arrange(caldt, ID, PERMNO) %>%
    distinct(caldt, ID, PERMNO)  
  
  ix=duplicated(MF[,c("caldt","ID","PERMNO")])
  ix=which(ix==T)
  if(length(ix)>0){
    MF=MF[-ix,]
    
  }
  # Creating Characteristic Selectivity (CS) Measure
  
  # Calculate CS based on Equally-Weighted Return
  MF <- MF %>%
    group_by(caldt, ID) %>%
    mutate(
      Weights = (PRC * Shares) / suma(PRC * Shares),
      Weights = ifelse(is.na(FEWBAR), NA, Weights / suma(Weights)), # Normalizing weights
      FCSE = suma(Weights * (FQRet - FEWBAR)) # Calculating Forward CS based on Equally-Weighted Return
    ) %>%
    ungroup()
  
  # Calculate CS based on Value-Weighted Return
  MF <- MF %>%
    group_by(caldt, ID) %>%
    mutate(
      Weights = (PRC * Shares) / suma(PRC * Shares),
      Weights = ifelse(is.na(FVWBAR), NA, Weights / suma(Weights)), # Normalizing weights
      FCSV = suma(Weights * (FQRet - FVWBAR)) # Calculating Forward CS based on Value-Weighted Return
    ) %>%
    ungroup()
  
  # Transforming at Fund Level and Setting Variable Labels
  MF <- MF %>%
    select(caldt, ID,  crsp_portno, FCSE, FCSV) %>%
    distinct() %>%
    arrange(caldt, ID) %>%
    set_variable_labels(
      .labels = c(
        "Current Date", "ID Fund", 
         "ID Fund: CRSP", 
        "Forward Characteristic Selectivity: 125 Portfolios on EWBAR / DGTW (1997)",
        "Forward Characteristic Selectivity: 125 Portfolios on VWBAR / DGTW (1997)"
      )
    )
  
  
  # Return the final dataset
  return(MF)
}

# Calculate CS for years 2000 to 2020
Y <- 2000:2020
QuarterlyCRSPBAR <- read_dta("QuarterlyCRSPBAR.dta")
DATA <- lapply(Y, CS, QuarterlyStockBAR = QuarterlyCRSPBAR)
DATA1 <- do.call(rbind, DATA)

# Final data preparation and export
DATA1 <- DATA1 %>%
  arrange(ID, caldt) %>%
  distinct() %>%
  group_by(ID) %>%
  mutate(CSE = lag(FCSE, 1), # CS is the lagged version, i.e., previous holdings and prices with current returns.
         CSV = lag(FCSV, 1)) %>%
  ungroup() %>%
  select(caldt, ID,  CSE, CSV)

# Export your data on CS