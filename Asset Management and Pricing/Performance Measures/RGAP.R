# Load required libraries
library(haven)       # For reading .dta files
library(dplyr)       # For data manipulation
library(lubridate)   # For date-time functions
library(labelled)    # For working with labelled data
library(sjlabelled)  # For labelling data
library(stringr)     # For string manipulation
library(DescTools)   # For descriptive statistics tools

# Set the working directory to the location of the Portfolio Level Variables data
setwd("D:/DATOS/PortolioLevelVariables")

# Define 'suma' function to calculate the sum of a vector, handling NA values
suma <- function(df) {
  if (all(is.na(df))) {
    sum <- NA  # Return NA if all values are NA
  } else {
    sum <- sum(df, na.rm = TRUE)  # Calculate sum, ignoring NA values
  }
  return(sum)
}

# Import Stock Level Information from a .dta file
QuarterlyStock <- read_dta("D:/DATOS/CRSP_STOCK/QuarterlyStock.dta")

# Process Returns from CRSP stock (Quarterly frequency)
# PERMNO is the unique identifier for each stock
# QRet is the cumulative within-quarter of monthly log-returns
# The script calculates the lead of QRet (future quarterly return) for each stock
QuarterlyStock <- QuarterlyStock %>%
  group_by(PERMNO) %>%
  mutate(FQRet = lead(QRet)) %>%  # Calculate lead of QRet
  ungroup()
names(QuarterlyStock)[1] <- "caldt"  # Rename the first column to 'caldt'

# Define the PM function for calculating RGAP measures for funds
# This function processes mutual fund holdings data and calculates specific financial metrics.
PM <- function(y, QuarterlyStock, Indexes_Weights, FTSE_Rusell, s) {
  
  # Import Mutual Fund Holdings for a given year 'y'
  MFHoldings <- read_dta(paste("D:/DATOS/Mutual Fund Holdings/Both/MFHoldings_", y, ".dta", sep = ""))
  MFHoldings[,"PERMNO"] <- NULL  # Remove 'PERMNO' column
  
  # Clean and arrange MFHoldings data
  MFHoldings <- MFHoldings %>%
    arrange(Quarter, ID, TICKER) %>%
    distinct() %>%
    mutate(NCUSIP = CUSIP) %>%
    filter(!(TICKER == "" | is.na(TICKER)) | !(NCUSIP == "" | is.na(NCUSIP)))
  
  # Drop duplicated holdings (bad reports)
  ix <- which(duplicated(MFHoldings[, c("caldt", "ID", "TICKER", "NCUSIP")]))
  if (length(ix) > 0) {
    MFHoldings <- MFHoldings[-ix, ]
  }
  
  # [The process continues for TICKER and NCUSIP correction and matching]
  # Duplicated tickers on Holdings: Bad Reports
  ix=duplicated(MFT[,c("caldt","ID","TICKER")])
  ix=which(ix==T)
  if(length(ix)>0){
    MFT=MFT[-ix,]
  }
  
  
  
  
  # Match by ncusip: Correction of CUSIP Holdings
  MFNC=MFHoldings # Holdings to match by TICKER
  # Drop ticker that are non-identified: aVOID DUPLICATED MERGE
  ix=which(MFNC$NCUSIP==""| is.na(MFNC$NCUSIP))
  if(length(ix)>0){
    MFNC=MFNC[-ix,] 
  }
  # Duplicated tickers on Holdings: Bad Reports
  ix=duplicated(MFNC[,c("caldt","ID","NCUSIP")])
  ix=which(ix==T)
  if(length(ix)>0){
    MFNC=MFNC[-ix,]
  }
  
  # Merge Quarterly stock information for both TICKER and NCUSIP
  # This section involves merging the stock data with the MFHoldings data
  # based on TICKER and NCUSIP, and then combining these datasets.
  # Merging Quarterly Stock: tICKER
  QS1=QuarterlyStock; QS1[,c("NCUSIP","CUSIP")]=NULL;QS1=distinct(QS1)
  ix=duplicated(QS1[,c("caldt","PERMNO","TICKER")])
  ix=which(ix==T)
  if(length(ix)>0){
    QS1=QS1[-ix,]
  }
  
  MFT1=inner_join(MFT,QS1)
  
  # Merging Quarterly Stock: NCUSIP
  QS1=QuarterlyStock; QS1[,c("CUSIP","TICKER")]=NULL;QS1=distinct(QS1)
  ix=duplicated(QS1[,c("caldt","PERMNO","NCUSIP")])
  ix=which(ix==T)
  if(length(ix)>0){
    QS1=QS1[-ix,]
  }
  
  MFNC1=inner_join(MFNC,QS1)
  
  MF=distinct(rbind(MFT1,MFNC1))
  MF=MF%>%arrange(caldt,ID,PERMNO)
  
  ix=duplicated(MF[,c("caldt","ID","PERMNO")])
  ix=which(ix==T)
  if(length(ix)>0){
    MF=MF[-ix,]
    
  }
  
  
  
  # Create FRH (current weights with future returns) and PGRet (Gross Return) variables
  # This involves group-wise operations on MFHoldings data to calculate the weighted returns.
  # CREATING THE VARIABLES
  # FRH (current weights with future returns)
  MF=MF%>%group_by(caldt,ID)%>%mutate(Weights=(PRC*Shares)/suma(PRC*Shares))%>%
    mutate(Weights=ifelse(is.na(FQRet),NA,Weights))%>%
    mutate(NWeights=Weights/suma(Weights))%>%
    mutate(FRH=suma(NWeights*FQRet))%>%ungroup()
  
  
  
  # CREATING THE VARIABLES
  # Gross Return (current wights with current returns)
  MF=MF%>%group_by(caldt,ID)%>%mutate(Weights=(PRC*Shares)/suma(PRC*Shares))%>%
    mutate(Weights=ifelse(is.na(QRet),NA,Weights))%>%
    mutate(NWeights=Weights/suma(Weights))%>%
    mutate(PGRet=suma(NWeights*Return))%>%ungroup()
  
  
  
  # Transform data to Fund Level and label the variables
  MF <- MF %>%
    select(caldt, ID, TName, FName, FundId, wficn, crsp_portno, FRH, PGRet) %>%
    distinct() %>%
    arrange(caldt, ID)
  
  # Define labels for the variables in the dataset
  L <- c("Current Date", "ID Fund", "Trust Name", "Fund Name",
         "ID Fund: MsD", "ID Fund: MFLINKS", "ID Fund: CRSP",
         "Future Returns by Hypothetical Keeping the Same Portfolio",
         "Current Gross Returns at Quarter-End")
  
  MF <- set_variable_labels(MF, .labels = L)
  
  # Write the processed data to a .dta file
  write_dta(MF, paste("PM", y, ".dta", sep = ""))
  
  return(MF)
}


# Define a sequence of years for analysis
Y <- seq(2000, 2020, 1)

# Apply the PM function to each year in the sequence
# 'PM' function calculates RGAP measures for mutual funds
DATA <- lapply(as.list(Y), PM, QuarterlyStock = QuarterlyStock, Indexes_Weights = Indexes_Weights, FTSE_Rusell = FTSE_Rusell, s = s)

# Combine the data from all years into a single dataframe
DATA1 <- do.call(rbind, DATA)

# Import monthly portfolio returns and summary data
MonthlyPortfolioReturns <- read_dta("D:/DATOS/CRSP Mutual funds/Value-Weighted Portfolios/MonthlyPortfolioReturns.dta")
MonthlyPortfolioSummary <- read_dta("D:/DATOS/CRSP Mutual funds/Value-Weighted Portfolios/MonthlyPortfolioSummary.dta")

# Merge the summary and returns data
auxdata <- left_join(MonthlyPortfolioSummary, MonthlyPortfolioReturns)

# Select and distinct the relevant columns
auxdata <- auxdata %>%
  select(caldt, ID, crsp_portno, mret, exp_ratio) %>%
  distinct()

# Process the data to calculate quarterly expenses and returns
# This includes linear interpolation of annualized expenses and calculation of cumulative gross returns
auxdata <- auxdata %>%
  arrange(ID, caldt) %>%
  mutate(QExpenses = exp_ratio / 4, GR = 1 + mret, Year = year(caldt), Quarter = quarter(caldt)) %>%
  mutate(GR1 = ifelse(is.na(GR), 1, GR)) %>%
  group_by(ID, Year, Quarter) %>%
  mutate(CGR = cumprod(GR1)) %>%
  mutate(CGR1 = ifelse(CGR == 1, NA, CGR)) %>%
  mutate(pqret = CGR1 - 1) %>%
  mutate(qret = ifelse(length(sum(!is.na(pqret))) > 0,
                       tail(pqret[which(!is.na(pqret))], 1),
                       NA)) %>%
  ungroup() %>%
  mutate(Month = months(caldt)) %>%
  filter(Month %in% c("March", "June", "September", "December")) %>%
  select(caldt, ID, crsp_portno, QExpenses, qret) %>%
  distinct()

# Merge the processed auxiliary data with the RGAP measures data
RData <- left_join(auxdata, DATA1)

# Process the RData dataframe to calculate the Return Gap (RGAP)
RData <- RData %>%
  arrange(ID, caldt) %>%  # Arrange data by Fund ID and Date
  group_by(ID) %>%
  mutate(RH = lag(FRH, 1)) %>%  # Calculate hypothetical current gross return of not doing anything
  ungroup()

# Calculate the Return Gap (RGAP)
# RGAP is the difference between what the portfolio realized and what it would have received by not doing anything.
RData <- RData %>%
  mutate(RGAP = qret - (RH - QExpenses)) %>%  # Compute RGAP
  select(caldt, ID, crsp_portno, PGRet, RH, RGAP) %>%
  distinct()

# Set labels for the variables in RData for clarity
L <- c("Current Date", "ID Fund", "ID Fund: CRSP",
       "Current Gross Returns at Quarter-End",
       "Current Returns by Hypothetical Keeping the Same Portfolio",
       "Return GAP")

RData <- set_variable_labels(RData, .labels = L)

# Export the processed data to your preferred format
