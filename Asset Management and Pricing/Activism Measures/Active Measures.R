# This script calculates Active Share (AF), Active Overlap (AFO), and Active ESG Overlap (AFE) for mutual funds.
# AF is based on Cremers and Petajisto (2009) and Petajisto (2013) methodologies.
# AFO and AFE are extensions incorporating insights from Avramov, Cheng, Hameed (2020) and Stambaugh, Yu, Yuan (2012; 2017).

# Required Libraries
library(haven)
library(dplyr)
library(lubridate)
library(labelled)
library(sjlabelled)
library(stringr)
library(DescTools)

# Setting the working directory
# setwd("yourdirectory")

# Define a function to handle NA values in summation
suma <- function(df){
  if (all(is.na(df))){
    return(NA)
  } else {    
    return(sum(df, na.rm = TRUE))
  }
}

# Importing data sets
# Stock Level Information - Quarterly data: Info on Prices, OI (Misspricing), and ESG 
QuarterlyStock <- read_dta("QuarterlyStock.dta")

# Index Market holdings FTSE RUSSEL - Monthly data
Indexes_Weights <- read_dta("Indexes_Weights_1990_2020.dta")
lubridate::day(Indexes_Weights$Date) <- 28

# Process and filter Indexes_Weights data
Indexes_Weights <- Indexes_Weights %>%
  select(Date, CUSIP, Ticker, Name, ESCode, EconSector, Russell1000, Russell2000, RussellMC,
         R1000_WT, R1000G_WT, R1000V_WT, R2000_WT, R2000G_WT, R2000V_WT, RMIDC_WT, RMIDCG_WT, RMIDCV_WT) %>%
  distinct() %>%
  filter(Date > "2000-01-01", Date < "2020-12-31", !(Russell1000 == "N" & Russell1000 == "N" & RussellMC == "N")) %>%
  distinct()

names(Indexes_Weights)[1] <- "caldt"
names(Indexes_Weights)[3] <- "TICKER"

# Importing Fund Benchmark data from FTSE Rusell (Morningstar Direct)
# Rusell 1000, 2000, Mid-Cap : Growth, Value
FTSE_Rusell <- read_dta("FTSE_Rusell_Equity.dta") 
ix <- which(FTSE_Rusell$FTSERussellBenchmark %in% c("", "4746"))
FTSE_Rusell <- FTSE_Rusell[-ix,]

# Process and filter FTSE_Rusell data
FTSE_Rusell <- FTSE_Rusell %>%
  mutate(IndexBenchmark = sapply(FTSE_Rusell$FTSERussellBenchmark, gsub, pattern=" TR USD", replacement = "")) %>%
  select(FundId, IndexBenchmark) %>%
  arrange(IndexBenchmark, FundId) %>%
  distinct()

# Clean up environment
rm(list = setdiff(ls(), c("FTSE_Rusell", "Indexes_Weights", "QuarterlyStock", "suma")))
gc()

# Portfolio Measures Function (PM)
PM <- function(y, QuarterlyStock, Indexes_Weights, FTSE_Rusell){
  # Import Mutual Fund Holdings for year 'y'
  # Import and Process Mutual Fund Holdings
  # Loading Mutual Fund Holdings for year 'y'
  MFHoldings <- read_dta(paste("MFHoldings_", y, ".dta", sep = ""))
  MFHoldings[,"PERMNO"] <- NULL
  
  # Arrange and remove duplicates to ensure data integrity
  # Arrange by Quarter, ID, and TICKER for a systematic structure
  # Distinct() ensures we only have unique entries
  # Filter out entries where TICKER or NCUSIP is missing or empty
  MFHoldings <- MFHoldings %>%
    arrange(Quarter, ID, TICKER) %>%
    distinct() %>%
    mutate(NCUSIP = CUSIP) %>%
    filter(!(TICKER == "" | is.na(TICKER)) | !(NCUSIP == "" | is.na(NCUSIP)))
  
  # Identify and Remove Duplicated Holdings to address potential data quality issues
  # Duplicates might indicate bad reports or data entry errors
  ix <- duplicated(MFHoldings[, c("caldt", "ID", "TICKER", "NCUSIP")])
  ix <- which(ix == TRUE)
  if(length(ix) > 0){
    MFHoldings <- MFHoldings[-ix,]
  }
  
  # Correcting Holdings for Database Matching
  # This section ensures that holdings are correctly matched in the database by both TICKER and NCUSIP
  
  # Match by Ticker: Correction of TICKER in Holdings
  # Separate holdings subset for TICKER matching
  MFT <- MFHoldings
  
  # Remove unidentified tickers to prevent duplicated merges
  # This step is crucial for data integrity
  ix <- which(MFT$TICKER == "" | is.na(MFT$TICKER))
  if(length(ix) > 0){
    MFT <- MFT[-ix,]
  }
  
  # Remove duplicated tickers in Holdings
  # Duplicated tickers could indicate incorrect or redundant data
  ix <- duplicated(MFT[, c("caldt", "ID", "TICKER")])
  ix <- which(ix == TRUE)
  if(length(ix) > 0){
    MFT <- MFT[-ix,]
  }
  
  # Match by NCUSIP: Correction of CUSIP in Holdings
  # Separate holdings subset for NCUSIP matching
  MFNC <- MFHoldings
  
  # Remove holdings with unidentified NCUSIP to avoid duplicated merges
  ix <- which(MFNC$NCUSIP == "" | is.na(MFNC$NCUSIP))
  if(length(ix) > 0){
    MFNC <- MFNC[-ix,]
  }
  
  # Remove duplicated NCUSIP in Holdings
  # Similar to TICKER, duplicated NCUSIPs are removed to maintain data quality
  ix <- duplicated(MFNC[, c("caldt", "ID", "NCUSIP")])
  ix <- which(ix == TRUE)
  if(length(ix) > 0){
    MFNC <- MFNC[-ix,]
  }
  
  # Merging Quarterly Stock Information with Holdings
  # This section combines quarterly stock information with mutual fund holdings based on TICKER and NCUSIP
  
  # Merge using TICKER
  # Prepare a version of QuarterlyStock without NCUSIP and CUSIP for TICKER merge
  QS1 <- QuarterlyStock
  QS1[, c("NCUSIP", "CUSIP")] <- NULL
  QS1 <- distinct(QS1)
  
  # Remove duplicated entries based on caldt, PERMNO, and TICKER
  # Ensuring data uniqueness is crucial for accurate merging
  ix <- duplicated(QS1[, c("caldt", "PERMNO", "TICKER")])
  ix <- which(ix == TRUE)
  if(length(ix) > 0){
    QS1 <- QS1[-ix,]
  }
  
  # Perform the inner join with MFT (Mutual Fund Holdings matched by TICKER)
  MFT1 <- inner_join(MFT, QS1)
  
  # Merge using NCUSIP
  # Prepare a version of QuarterlyStock without CUSIP and TICKER for NCUSIP merge
  QS1 <- QuarterlyStock
  QS1[, c("CUSIP", "TICKER")] <- NULL
  QS1 <- distinct(QS1)
  
  # Remove duplicated entries based on caldt, PERMNO, and NCUSIP
  ix <- duplicated(QS1[, c("caldt", "PERMNO", "NCUSIP")])
  ix <- which(ix == TRUE)
  if(length(ix) > 0){
    QS1 <- QS1[-ix,]
  }
  
  # Perform the inner join with MFNC (Mutual Fund Holdings matched by NCUSIP)
  MFNC1 <- inner_join(MFNC, QS1)
  
  # Combine and finalize the merged data
  # Distinct rows are selected to avoid duplicates from merging operations
  MF <- distinct(rbind(MFT1, MFNC1))
  MF <- MF %>% arrange(caldt, ID, PERMNO)
  
  # Remove any remaining duplicates in the final merged data
  ix <- duplicated(MF[, c("caldt", "ID", "PERMNO")])
  ix <- which(ix == TRUE)
  if(length(ix) > 0){
    MF <- MF[-ix,]
  }
  
  
  # Merging FTSE Index Holding Information with Mutual Fund Data
  # This section integrates benchmark market index information from FTSE Russel with the mutual fund data
  
  # Merge Mutual Fund data with FTSE Russel Index Benchmark Information
  # Performing a left join ensures all mutual fund data is retained while adding matching index information
  MF <- left_join(MF, FTSE_Rusell)
  
  # Select relevant columns and remove duplicates for clean and focused data
  MF <- MF %>%
    select(caldt, ID, crsp_portno, IndexBenchmark, PERMNO, TICKER, NCUSIP,
           StkName, COMNAM, SIC10, MWI, Shares, PRC, OI, ESG) %>%
    distinct()
  
  # Merge Mutual Fund data with Index Weights Information
  # This merge is based on the caldt and TICKER fields
  # Removing CUSIP column to ensure proper merge based on TICKER
  MF[,"CUSIP"] <- NULL
  MF <- distinct(MF)
  MF <- left_join(MF, Indexes_Weights, by = c("caldt", "TICKER"))
  
  # Select relevant columns post-merge and ensure distinctness
  # This step finalizes the data preparation by selecting necessary fields and removing any duplicates
  MF <- MF %>%
    select(caldt, ID, crsp_portno, IndexBenchmark, PERMNO, TICKER, NCUSIP,
           StkName, COMNAM, Name, SIC10, MWI, Shares, PRC, OI, ESG,
           R1000_WT, R1000G_WT, R1000V_WT,
           R2000_WT, R2000G_WT, R2000V_WT,
           RMIDC_WT, RMIDCG_WT, RMIDCV_WT) %>%
    distinct()
  
  # Clean up workspace to free memory
  # Removing unnecessary objects from the environment and calling garbage collection
  #rm(list = setdiff(ls(), c("MF", "suma", "s", "y")))
  #gc()
  
  # Creating Variables for Analysis
  # This section focuses on computing Active Share (AF) and handling NA values in index weights
  
  # Handling Missing Index Weights
  # In the dataset, NA values in index holdings imply the absence of a particular stock in the index. 
  # For the purpose of calculation, these NAs are treated as zeros.
  # This step is vital as it impacts the computation of Active Share
  MF <- MF %>%
    mutate(
      R1000_WT = ifelse(is.na(R1000_WT), 0, R1000_WT),
      R1000G_WT = ifelse(is.na(R1000G_WT), 0, R1000G_WT),
      R1000V_WT = ifelse(is.na(R1000V_WT), 0, R1000V_WT),
      R2000_WT = ifelse(is.na(R2000_WT), 0, R2000_WT),
      R2000G_WT = ifelse(is.na(R2000G_WT), 0, R2000G_WT),
      R2000V_WT = ifelse(is.na(R2000V_WT), 0, R2000V_WT),
      RMIDC_WT = ifelse(is.na(RMIDC_WT), 0, RMIDC_WT),
      RMIDCG_WT = ifelse(is.na(RMIDCG_WT), 0, RMIDCG_WT),
      RMIDCV_WT = ifelse(is.na(RMIDCV_WT), 0, RMIDCV_WT)
    )
  
  # Calculating Active Share (AF) for Mutual Funds
  # AF measures the fraction of a fund's portfolio that differs from its benchmark index.
  
  # Group data by date and fund ID for calculation
  # Then, compute the weights of each holding in the fund's portfolio
  MF <- MF %>%
    group_by(caldt, ID) %>%
    mutate(
      Weights = (PRC * Shares) / suma(PRC * Shares)
    ) %>%
    # Compute AF based on the fund's benchmark index
    # AF is calculated as half the sum of the absolute difference between fund weights and index weights
    mutate(
      AF = ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 1000",
                  0.5 * suma(abs(Weights - R1000_WT)),
                  ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 1000 Growth",
                         0.5 * suma(abs(Weights - R1000G_WT)),
                         ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 1000 Value",
                                0.5 * suma(abs(Weights - R1000V_WT)),
                                ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 2000",
                                       0.5 * suma(abs(Weights - R2000_WT)),
                                       ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 2000 Growth",
                                              0.5 * suma(abs(Weights - R2000G_WT)),
                                              ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 2000 Value",
                                                     0.5 * suma(abs(Weights - R2000V_WT)),
                                                     ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell Mid Cap",
                                                            0.5 * suma(abs(Weights - RMIDC_WT)),
                                                            ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell Mid Cap Growth",
                                                                   0.5 * suma(abs(Weights - RMIDCG_WT)),
                                                                   ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell Mid Cap Value",
                                                                          0.5 * suma(abs(Weights - RMIDCV_WT)),
                                                                          NA # Assign NA if none of the benchmarks match
                                                                   )
                                                            )
                                                     )
                                              )
                                       )
                                )
                         )
                  )
      ) %>%
        ungroup() %>%
        distinct()
      
      # This code block ends the calculation of Active Share (AF) for each fund
      
  
      # Calculating Active Overlap (AFO) for Mutual Funds
      # AFO measures the degree of overlap between a fund's portfolio and its benchmark index, adjusted for Overlap Index (OI).
      
      # Group data by date and fund ID for calculation
      # Compute the weights of each holding in the fund's portfolio
      MF <- MF %>%
        group_by(caldt, ID) %>%
        mutate(
          Weights = (PRC * Shares) / suma(PRC * Shares)
        ) %>%
        # Compute AFO based on the fund's benchmark index and Overlap Index (OI)
        # AFO is calculated as half the sum of the product of the difference in weights and OI
        mutate(
          AFO = ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 1000",
                       0.5 * suma((Weights - R1000_WT) * OI),
                       ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 1000 Growth",
                              0.5 * suma((Weights - R1000G_WT) * OI),
                              ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 1000 Value",
                                     0.5 * suma((Weights - R1000V_WT) * OI),
                                     ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 2000",
                                            0.5 * suma((Weights - R2000_WT) * OI),
                                            ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 2000 Growth",
                                                   0.5 * suma((Weights - R2000G_WT) * OI),
                                                   ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell 2000 Value",
                                                          0.5 * suma((Weights - R2000V_WT) * OI),
                                                          ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell Mid Cap",
                                                                 0.5 * suma((Weights - RMIDC_WT) * OI),
                                                                 ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell Mid Cap Growth",
                                                                        0.5 * suma((Weights - RMIDCG_WT) * OI),
                                                                        ifelse(Mode(IndexBenchmark, na.rm = TRUE) == "Russell Mid Cap Value",
                                                                               0.5 * suma((Weights - RMIDCV_WT) * OI),
                                                                               NA # Assign NA if none of the benchmarks match
                                                                        )
                                                                 )
                                                          )
                                                   )
                                            )
                                     )
                              )
                       )
          )
        ) %>%
        ungroup() %>%
        distinct()
      
      # This code block concludes the calculation of Active Overlap (AFO)
      
  
      MF=MF%>%group_by(caldt,ID)%>%
        mutate(Weights=(PRC*Shares)/suma(PRC*Shares))%>%
        mutate(AFE=ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell 1000",
                          0.5*suma((Weights-R1000_WT)*ESG),
                          ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell 1000 Growth",
                                 0.5*suma((Weights-R1000G_WT)*ESG),
                                 ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell 1000 Value",
                                        0.5*suma((Weights-R1000V_WT)*ESG),
                                        ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell 2000",
                                               0.5*suma((Weights-R2000_WT)*ESG),
                                               ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell 2000 Growth",
                                                      0.5*suma((Weights-R2000G_WT)*ESG),
                                                      ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell 2000 Value",
                                                             0.5*suma((Weights-R2000V_WT)*ESG),
                                                             ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell Mid Cap",
                                                                    0.5*suma((Weights-RMIDC_WT)*ESG),
                                                                    ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell Mid Cap Growth",
                                                                           0.5*suma((Weights-RMIDCG_WT)*ESG),
                                                                           ifelse(Mode(IndexBenchmark,na.rm=T)=="Russell Mid Cap Value",
                                                                                  0.5*suma((Weights-RMIDCV_WT)*ESG),
                                                                                  NA # Falso todos los benchmark asi que haga NA
                                                                           ) # Cierre del 9 If: R1000 & R1000G R1000V R2000 R2000G R2000V RMID RMIDCG
                                                                    )# Cierre del 8vo If: Falso  R1000 & R1000G R1000V R2000 R2000G R2000V RMID
                                                             )# Cierre del Septimo IF: Falso  R1000 & R1000G R1000V R2000 R2000G R2000V
                                                      ) # Cierre del Sexto If: Falso  R1000 & R1000G R1000V R2000 R2000G
                                               )# Cierre del Quinto If: Falso  R1000 & R1000G R1000V R2000
                                        )#  Cierre del cuarto If: Falso  R1000 & R1000G R1000V
                                 )# Cierre del tercer If: Falso R1000 & R1000G
                          ) # Cierre Segundo If: Falso R1000
                          
        )# Cierre del primer If R1000
        )%>% # Cierre del mutate que genera AF
        ungroup()%>%distinct()
      
      
# Transforming Data to Fund Level
      
MF=MF%>%select(caldt,ID,crsp_portno,IndexBenchmark,
                     AF,AFO, AFE)%>%distinct()%>%arrange(caldt,ID)
      
      

      return(MF)    
      
}

Y=seq(2000,2020,1)
DATA=lapply(as.list(Y),PM,QuarterlyStock=QuarterlyStock,Indexes_Weights=Indexes_Weights,FTSE_Rusell=FTSE_Rusell)
DATA1=do.call(rbind,DATA)

