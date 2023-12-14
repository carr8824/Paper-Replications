# Load necessary libraries
library(readr)
library(haven)
library(dplyr)
library(labelled)
library(sjlabelled)
library(lubridate)
library(sjmisc)
library(runner)
library(RcppRoll)
library(rollRegress)
library(zoo)
library(parallel)
library(DescTools)

# Set working directory to the specified path
setwd("D:/DATOS/CRSP Mutual funds")

# Define the regression function
# This function performs multiple regression analyses for different financial models
# on a specified window of data.
regress <- function(SW, samplef) {
  # Perform regressions using different financial models.
  # Each regression is wrapped in a tryCatch to handle errors gracefully.
  
  # CAPM Model
  reg1 <- tryCatch(lm((mret-rf) ~ mktrf, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
  
  # Fama-French Three-Factor Model
  reg3 <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
  
  # Carhart Four-Factor Model
  reg4 <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml + umd, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
  
  
  # Additional regressions incorporating Pastor and Stambaugh and Sadka factors
  reg4ps <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml + umd + PSTrad, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
  reg4sk <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml + umd + SKAP1, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])

  # Extract the number of observations for each regression, if available
  Nob <- if (length(reg1) > 1) nobs(reg1) else 0
  Nob3 <- if (length(reg3) > 1) nobs(reg3) else 0
  Nob4 <- if (length(reg4) > 1) nobs(reg4) else 0
  
  Nob4ps <- if (length(reg4ps) > 1) nobs(reg4ps) else 0
  Nob4sk <- if (length(reg4sk) > 1) nobs(reg4sk) else 0
  
  # Initialize variables to store regression coefficients and statistics
  Alpha <- Alpha3 <- Alpha4 <- Alphaps <-  Alphask <- NA
  
  # Extract coefficients and statistics from each regression model, if successful
  if (class(reg1) == "lm") {
    Alpha <- coef(reg1)[1]
  }
  
  if (class(reg3) == "lm") {
    Alpha3 <- coef(reg3)[1]
  }
  
  if (class(reg4) == "lm") {
    Alpha4 <- coef(reg4)[1]
  }
  
  if (class(reg4ps) == "lm") {
    Alphaps <- coef(reg4ps)[1]
  }
  
  if (class(reg4sK) == "lm") {
    AlphasK <- coef(reg4sK)[1]
  }
  
  # Repeat the process for other regression models...
  
  # Concatenate the estimated information for output
  Nobs <- cbind(Nob, Nob3, Nob4, Nob4ps, Nob4sk)
  Res <- cbind(Alpha, Alpha3, Alpha4, Alphaps, Alphask)
  return(cbind(Nobs, Res))
}


# Define the rolling window function for linear OLS regression
# This function applies a rolling window approach to a dataset for regression analysis.
rolling <- function(samplef, window) {
  # Calculate the sample size from the input dataset
  samplesize <- nrow(samplef)
  
  # Generate start and end indices for each rolling window
  Start <- 1:(samplesize - window + 1)
  End <- window:samplesize
  SWind <- cbind(Start, End)
  
  # Apply the regression function to each window and transpose the results
  # 't' transposes the matrix to align rows with variables and columns with observations
  data <- t(apply(SWind, 1, regress, samplef = samplef))
  
  # Create a matrix of NA values to prepend to the data
  # This step ensures the output matrix has the correct dimensions
  seeddata <- matrix(NA, nrow = window - 1, ncol = ncol(data))
  
  # Combine the seed data with the actual data
  # This alignment is necessary for datasets with rolling window regressions
  Data <- rbind(seeddata, data)
  
  # Set column names for the output data frame
  # These names correspond to various regression statistics and coefficients
  colnames(Data) <- c("Nob", "Nob3", "Nob4", "Nob4ps", "Nob4sk",
                      "Alpha", "Alpha3", "Alpha4",
                      "Alphaps", "Alphask")
  
  Res <- cbind(Alpha, Alpha3, Alpha4, Alphaps, Alphask)
  
  # Return the final data frame
  return(Data)
}

# Define the 'alphas' function
# This function enhances the calculation of alpha values for financial data,
# accommodating various factor models and handling data sparsity.
alphas <- function(Data, FId) {
  # Filter the data for the specified fund ID
  samplef <- filter(Data, ID == FId)
  
  # Check the number of rows in the filtered data to determine the window size for rolling averages
  
  # If the data has at least 36 rows
  if (nrow(samplef) >= 36) {
    # Compute rolling averages for 12, 24, and 36 months
    S12 <- rolling(samplef = samplef, window = 12)
    colnames(S12) <- paste(colnames(S12), 12, sep = "_")
    
    S24 <- rolling(samplef = samplef, window = 24)
    colnames(S24) <- paste(colnames(S24), 24, sep = "_")
    
    S36 <- rolling(samplef = samplef, window = 36)
    colnames(S36) <- paste(colnames(S36), 36, sep = "_")
    
    # Compile the results from all window sizes
    A <- cbind(S12, S24, S36)
    
    # If the data has between 24 and 36 rows
  } else if (nrow(samplef) < 36 & nrow(samplef) >= 24) {
    # Compute rolling averages for 12 and 24 months
    S12 <- rolling(samplef = samplef, window = 12)
    nms <- colnames(S12)
    colnames(S12) <- paste(colnames(S12), 12, sep = "_")
    
    S24 <- rolling(samplef = samplef, window = 24)
    colnames(S24) <- paste(colnames(S24), 24, sep = "_")
    
    # For 36 months, use NA values as placeholder
    S36 <- matrix(NA, nrow = nrow(samplef), ncol = 20)
    colnames(S36) <- paste(nms, 36, sep = "_")
    
    # Compile the results
    A <- cbind(S12, S24, S36)
    
    # If the data has between 12 and 24 rows
  } else if (nrow(samplef) < 24 & nrow(samplef) >= 12) {
    # Compute rolling average for 12 months
    S12 <- rolling(samplef = samplef, window = 12)
    nms <- colnames(S12)
    colnames(S12) <- paste(colnames(S12), 12, sep = "_")
    
    # For 24 and 36 months, use NA values as placeholders
    S24 <- S36 <- matrix(NA, nrow = nrow(samplef), ncol = 20)
    colnames(S24) <- colnames(S36) <- paste(nms, c(24, 36), sep = "_")
    
    # Compile the results
    A <- cbind(S12, S24, S36)
    
    # If the data has less than 12 rows
  } else {
    # Define column names for placeholders
    nms <- c("Nob", "Nob3", "Nob4", "Nob4ps", "Nob4sk",
             "Alpha", "Alpha3", "Alpha4", "Alphaps", "Alphask")
    
    # Use NA values as placeholders for all window sizes
    S12 <- S24 <- S36 <- matrix(NA, nrow = nrow(samplef), ncol = 10)
    colnames(S12) <- colnames(S24) <- colnames(S36) <- paste(nms, c(12, 24, 36), sep = "_")
    
    # Compile the results
    A <- cbind(S12, S24, S36)
  }
  
  # Define key variables for the output data frame (your Identifier of a fund)
  # Here depends on your data, in my case a have the following identifiers (Check Data-Matching Repository for details)
  variable <- c("caldt", "ID", "FundId", "wficn", "crsp_portno")
  
  # Combine the filtered data with the compiled alpha values
  DATA <- cbind(samplef[, variable], A)
  
  # Return the final data frame
  return(DATA)
}

####################################################
# Load Factors and Monthly Portfolio Returns data
FactorsData <- read_dta("FactorsData.dta")
MonthlyPortfolioReturns <- read_dta("MonthlyPortfolioReturns.dta")

# Merge Monthly Portfolio Returns with Factors Data
Data <- left_join(MonthlyPortfolioReturns, FactorsData)

# Extract unique Fund IDs from the Data
Fd <- unique(Data$ID)

# Initialize parallel processing cluster using all available cores
cl <- makeCluster(detectCores())

# Define functions and load necessary libraries on each node of the cluster
clusterEvalQ(cl, {
  library(dplyr)
  
  # Define 'regress' function for performing various financial regressions
  regress <- function(SW, samplef) {
    # Perform regressions using different financial models.
    # Each regression is wrapped in a tryCatch to handle errors gracefully.
    
    # CAPM Model
    reg1 <- tryCatch(lm((mret-rf) ~ mktrf, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
    
    # Fama-French Three-Factor Model
    reg3 <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
    
    # Carhart Four-Factor Model
    reg4 <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml + umd, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
    
    
    # Additional regressions incorporating Pastor and Stambaugh and Sadka factors
    reg4ps <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml + umd + PSTrad, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
    reg4sk <- tryCatch(lm((mret-rf) ~ mktrf + smb + hml + umd + SKAP1, data = samplef[SW[1]:SW[2], ]), error = function(e) e[1])
    
    # Extract the number of observations for each regression, if available
    Nob <- if (length(reg1) > 1) nobs(reg1) else 0
    Nob3 <- if (length(reg3) > 1) nobs(reg3) else 0
    Nob4 <- if (length(reg4) > 1) nobs(reg4) else 0
    
    Nob4ps <- if (length(reg4ps) > 1) nobs(reg4ps) else 0
    Nob4sk <- if (length(reg4sk) > 1) nobs(reg4sk) else 0
    
    # Initialize variables to store regression coefficients and statistics
    Alpha <- Alpha3 <- Alpha4 <- Alphaps <-  Alphask <- NA
    
    # Extract coefficients and statistics from each regression model, if successful
    if (class(reg1) == "lm") {
      Alpha <- coef(reg1)[1]
    }
    
    if (class(reg3) == "lm") {
      Alpha3 <- coef(reg3)[1]
    }
    
    if (class(reg4) == "lm") {
      Alpha4 <- coef(reg4)[1]
    }
    
    if (class(reg4ps) == "lm") {
      Alphaps <- coef(reg4ps)[1]
    }
    
    if (class(reg4sK) == "lm") {
      AlphasK <- coef(reg4sK)[1]
    }
    
    # Repeat the process for other regression models...
    
    # Concatenate the estimated information for output
    Nobs <- cbind(Nob, Nob3, Nob4, Nob4ps, Nob4sk)
    Res <- cbind(Alpha, Alpha3, Alpha4, Alphaps, Alphask)
    return(cbind(Nobs, Res))
  }
  
  # Define 'rolling' function to apply rolling window calculations
  rolling <- function(samplef, window) {
    # Calculate the sample size from the input dataset
    samplesize <- nrow(samplef)
    
    # Generate start and end indices for each rolling window
    Start <- 1:(samplesize - window + 1)
    End <- window:samplesize
    SWind <- cbind(Start, End)
    
    # Apply the regression function to each window and transpose the results
    # 't' transposes the matrix to align rows with variables and columns with observations
    data <- t(apply(SWind, 1, regress, samplef = samplef))
    
    # Create a matrix of NA values to prepend to the data
    # This step ensures the output matrix has the correct dimensions
    seeddata <- matrix(NA, nrow = window - 1, ncol = ncol(data))
    
    # Combine the seed data with the actual data
    # This alignment is necessary for datasets with rolling window regressions
    Data <- rbind(seeddata, data)
    
    # Set column names for the output data frame
    # These names correspond to various regression statistics and coefficients
    colnames(Data) <- c("Nob", "Nob3", "Nob4", "Nob4ps", "Nob4sk",
                        "Alpha", "Alpha3", "Alpha4",
                        "Alphaps", "Alphask")
    
    Res <- cbind(Alpha, Alpha3, Alpha4, Alphaps, Alphask)
    
    # Return the final data frame
    return(Data)
  }
})

# Parallel computation: Apply 'alphas' function to each Fund ID in the list
# 'parLapplyLB' is used for load balancing across the cluster
Data1 <- parLapplyLB(cl, as.list(Fd), alphas, Data = Data)

# Combine results into a single data frame
Data1 <- do.call(rbind, Data1)

# Stop and close the parallel processing cluster
stopCluster(cl)

L=c("Date", " ID Fund", "NSAR: Company Number","NSAR: Fund Number",
    "MsD: Fund Id","Wharton MFLINKS: Fund Id",
    "CRSP: Portfolio Number OR Fund Id",
    # 12 months window size for estimation (1 year)
    "Number Of Observatios [/12]: CAPM",
    "Number of Observations [/12]: FF4", 
    "Number of Observation [/12]: Pastor and Stamabaugh",
    "Number of Observation [/12]: Sadka",
    "Alpha CAPM: 12 Lags",
    "Alpha FF3: 12 Lags",
    "Alpha PS: 12 Lags",
    "Alpha SK: 12 Lags",
    # 24 months window size for estimation (2 year)
    "Number Of Observatios [/24]: CAPM",
    "Number of Observations [/24]: FF4", 
    "Number of Observation [/24]: Pastor and Stamabaugh",
    "Number of Observation [/24]: Sadka",
    "Alpha CAPM: 24 Lags",
    "Alpha FF3: 24 Lags",
    "Alpha PS: 24 Lags",
    "Alpha SK: 24 Lags",
    # 36 months window size for estimation (Three year)
    "Number Of Observatios [/36]: CAPM",
    "Number of Observations [/36]: FF4", 
    "Number of Observation [/36]: Pastor and Stamabaugh",
    "Number of Observation [/36]: Sadka",
    "Alpha CAPM: 36 Lags",
    "Alpha FF3: 36 Lags",
    "Alpha PS: 36 Lags",
    "Alpha SK: 36 Lags"
    )

Data1=set_variable_labels(Data1,.labels = L)

# Export your data (format you prefer)