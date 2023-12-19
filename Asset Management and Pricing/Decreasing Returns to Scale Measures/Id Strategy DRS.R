# Here we load the libraries relevant for performing doe tasks
library(tidyr)
library(haven)
library(dplyr)
library(ggplot2)
library(lubridate)
library(modelsummary)
library(sandwich) # Variance-covariance Matrix for standard errors
library(fixest) # To perform TWFE (Two-Way Fix effects) on OLS regressions
library(lmtest)
library(readxl)
library(sjlabelled)
library(labelled)

# Create functions that we will use in the demean process 

Suma=function(x){
  if(sum(is.na(x))==length(x)){
    r=NA
  }else{
    r=sum(x, na.rm=T)
  }
  return(r)
}


Mean=function(x){
  if(sum(is.na(x))==length(x)){
    r=NA
  }else{
    r=mean(x, na.rm=T)
  }
  return(r)
}


# Import the monthly data base 

setwd("YOUR DIRECTORY")

load("MMsDFundRegData.Rdata")


# We check duplicates and proceed to drop the observations

ix=duplicated(Sample1[,c("caldt", "FundId")])
ix=which(ix==T)
if(length(ix>0)){
  Sample1=Sample1[-ix, ]
  
}

# KEEP sAMPLE 2000-Jan to 2020-Dec
Sample1=Sample1%>%
  filter(caldt>"1999-12-28" & caldt< "2021-01-28")


Sample1=Sample1%>%arrange(FundId, caldt)%>%ungroup()

#### III) ESG Top 25 : No excluyen SRI, es decir si un fondo esta en el top 25 es ESG, ignorando si es SRI o no, en el caso contrario es igual. 
# ESG SCORE



# Risk-Adjusted Returns (Return - Benchmark)
# Dependent variable is the risk adjustged returns, as the benchmark returns are adjusted by risk
Sample1=Sample1%>%ungroup()%>%
  mutate(RANRet=FNRet-BenchGReturn, # Net Returns reported by Morningstar Direct
         RAGRet=FGRet-BenchGReturn, # Gross Returns
         RAGRetA=FGRetA-BenchGReturn, # Gross returns as Net Returns + Expenses 
         RAGRetB=FGRetB-BenchGReturn # Gross returns plus expenses 
  )


# Size Variables
# Size_Agg: Aggregated TNA of all share classes: Reported by Morningstar
# Size_ Cphv: Commprehensive size: Reported by Morningstar
# Size_ Thsr: Total sum of share classes calculated
Sample1=Sample1%>%arrange(FundId, caldt)%>%group_by(FundId)%>%
  mutate(LSize1=lag(Size_Agg, n=1, order_by = caldt),
         LSize2=lag(Size_Cphv, n=1, order_by = caldt),
         LSize3=lag(Size_TShr, 1, n=1, order_by = caldt),
         
         LSizeA1=lag(SizeA_Agg, n=1, order_by = caldt),
         LSizeA2=lag(SizeA_Cphv, n=1, order_by = caldt),
         LSizeA3=lag(SizeA_TShr, n=1, order_by = caldt),
         
         LTNA1=lag(AUM_Agg, n=1, order_by = caldt),
         LTNA2=lag(Aum_Cphv, n=1, order_by = caldt),
         LTNA3=lag(AUM_TShr, n=1, order_by = caldt),
         
         LATNA1=lag(AAUM_Agg, n=1, order_by = caldt),
         LATNA2=lag(AAum_Cphv, n=1, order_by = caldt),
         LATNA3=lag(AAUM_TShr, n=1, order_by = caldt)
  )%>%ungroup()

ix=which(Sample1$RAGRetB>1 | Sample1$RAGRetB < -1)
Sample1[ix, "RAGRetB"]=NA


########################################################
##########################REGRESION##########################
#########################################################

##################################################################
#    We proced to replicate the identification strategy DR2 (ZHOU) : Two stage least squares
#  Zhu, Min, 2018, Informative fund size, managerial skill, and investor rationality, Journal of Financial Economics 130, 114–134.

# Inicialy we demean the variables involved in the the regression to avoid positive bias.

# we create the variables that help us demean variables. 
# # IINCIALLY THE Fordward demean process: delete the mean to the future
ForwardMean=function(x){
  r=sapply(seq_along(x), function(i) Mean(x[i:length(x)]))
  #r[length(x)]=0 # LAST MEAN IS EQUAL TO the same value 
  # t : in 1 : (T-1)
  return(r)
} 


# We do the same but for the variable size that is in lags: We forward deman the lag variable
LagForwardMean=function(x){
  if(length(x)<2){
    r=NA
  }else{
    r=sapply(seq_along(x)[2:length(x)], function(i) Mean(x[(i-1):(length(x)-1)]))
    r=c(NA, r)
    #r[length(x)]=0 # LAST MEAN IS EQUAL TO the same value
    # t : in 1 : (T-1)
  }
  return(r)
} 




Sample1=Sample1%>%arrange(FundId, caldt)%>%group_by(FundId)%>%
  mutate(FMRANRet=ForwardMean(RANRet),
         FMRAGRet=ForwardMean(RAGRet),
         FMRAGRetA=ForwardMean(RAGRetA),
         FMRAGRetB=ForwardMean(RAGRetB),
         # The explanatory variables uses lag-forward
         FMLSize1=LagForwardMean(Size_Agg), # The function goes from 2 to(i-1)
         FMLSizeA1=LagForwardMean(SizeA_Agg),
         FMLTNA1=LagForwardMean(AUM_Agg),
         FMLATNA1=LagForwardMean(AAUM_Agg),
         
         FMLSize2=LagForwardMean(Size_Cphv), # The function goes from 2 to(i-1)
         FMLSizeA2=LagForwardMean(SizeA_Cphv),
         FMLTNA2=LagForwardMean(Aum_Cphv),
         FMLATNA2=LagForwardMean(AAum_Cphv),
         
         FMLSize3=LagForwardMean(Size_TShr), # The function goes from 2 to(i-1)
         FMLSizeA3=LagForwardMean(SizeA_TShr),
         FMLTNA3=LagForwardMean(AUM_TShr),
         FMLATNA3=LagForwardMean(AAUM_TShr)
  )%>%
  ungroup()%>%
  mutate(RFDRANRet = RANRet - FMRANRet,
         RFDRAGRet = RAGRet - FMRAGRet,
         RFDRAGRetA = RAGRetA - FMRAGRetA,
         RFDRAGRetB = RAGRetB - FMRAGRetB,
         
         RFDLSize1 = LSize1 - FMLSize1,
         RFDLSizeA1 = LSizeA1 - FMLSizeA1,
         RFDLTNA1 = LTNA1 - FMLTNA1,
         RFDLATNA1 = LATNA1 - FMLATNA1,
         
         RFDLSize2 = LSize2 - FMLSize2,
         RFDLSizeA2 = LSizeA2 - FMLSizeA2,
         RFDLTNA2 = LTNA2 - FMLTNA2,
         RFDLATNA2 = LATNA2 - FMLATNA2,
         
         RFDLSize3 = LSize3 - FMLSize3,
         RFDLSizeA3 = LSizeA3 - FMLSizeA3,
         RFDLTNA3 = LTNA3 - FMLTNA3,
         RFDLATNA3 = LATNA3 - FMLATNA3
  )


#                       Two Stage Regression


#                           First Stage


FirstStage <- lm(RFDLSize1~LSize1, 
                 data = Sample1
                 #, subset = !is.na(ESGD80)
)

FirstStageA <- lm(RFDLSizeA1~LSizeA1, 
                  data = Sample1
                  #, subset = !is.na(ESGD80)
)


FirstStageD <- lm(RFDLTNA1~LTNA1, 
                  data = Sample1
                  #, subset = !is.na(ESGD80)
)


FirstStageDA <- lm(RFDLATNA1~LATNA1, 
                   data = Sample1
                   #, subset = !is.na(ESGD80)
)





msummary(list(FirstStage, FirstStageA, FirstStageD, FirstStageDA),
         stars = c('*'=0.1,'**'=0.05,'***'=0.01),fmt=4,
         statistic="statistic",
         gof_omit =c("AIC|BIC|RMSE|Log.Lik"),
         #output="data.frame",
         title = "Demean Instrument",
         notes="t-statistic appear in parenthis (). ALL explanatory variables are lagged one period"
)


#                          Second Stage 
# Include the ESGD ESG Dummy to see ESG interaction
# 
Sample1=Sample1%>%ungroup()%>%
  mutate(FitRFDLSize1=coef(FirstStage)[1]+coef(FirstStage)[2]*LSize1,
         FitRFDLSizeA1=coef(FirstStageA)[1]+coef(FirstStageA)[2]*LSizeA1,
         FitRFDLTNA1=coef(FirstStageD)[1]+coef(FirstStageD)[2]*LTNA1,
         FitRFDLATNA1=coef(FirstStageDA)[1]+coef(FirstStageDA)[2]*LATNA1,
  )





SecondStage1D=lm(RFDRANRet~-1+FitRFDLTNA1,
                 data = Sample1)


SecondStage3D=lm(RFDRAGRet~-1+FitRFDLTNA1,
                 data = Sample1)

SecondStage4D=lm(RFDRAGRetA~-1+FitRFDLTNA1,
                 data = Sample1)

SecondStage5D=lm(RFDRAGRetB~-1+FitRFDLTNA1,
                 data = Sample1)


SecondStage1=lm(RFDRANRet~-1+FitRFDLSize1,
                data = Sample1)


SecondStage3=lm(RFDRAGRet~-1+FitRFDLSize1,
                data = Sample1)

SecondStage4=lm(RFDRAGRetA~-1+FitRFDLSize1,
                data = Sample1)

SecondStage5=lm(RFDRAGRetB~-1+FitRFDLSize1,
                data = Sample1)





SecondStage1DA=lm(RFDRANRet~-1+FitRFDLATNA1,
                  data = Sample1)

SecondStage3DA=lm(RFDRAGRet~-1+FitRFDLATNA1,
                  data = Sample1)

SecondStage4DA=lm(RFDRAGRetA~-1+FitRFDLATNA1,
                  data = Sample1)

SecondStage5DA=lm(RFDRAGRetB~-1+FitRFDLATNA1,
                  data = Sample1)



SecondStage1A=lm(RFDRANRet~-1+FitRFDLSizeA1,
                 data = Sample1)


SecondStage3A=lm(RFDRAGRet~-1+FitRFDLSizeA1,
                 data = Sample1)



SecondStage4A=lm(RFDRAGRetA~-1+FitRFDLSizeA1,
                 data = Sample1)

SecondStage5A=lm(RFDRAGRetB~-1+FitRFDLSizeA1,
                 data = Sample1)


msummary(list(SecondStage1D,SecondStage3D, SecondStage4D, SecondStage5D,
              SecondStage1,SecondStage3, SecondStage4, SecondStage5, 
              SecondStage1DA,SecondStage3DA, SecondStage4DA, SecondStage5DA,
              SecondStage1A,SecondStage3A, SecondStage4A, SecondStage5A),
         stars = c('*'=0.1,'**'=0.05,'***'=0.01),fmt=4,
         statistic="statistic",
         gof_omit =c("AIC|BIC|RMSE|Log.Lik"),
         coef_map = c("FitRFDLSize1" = 'Size',
                      "FitRFDLSizeA1" = 'Size',
                      "FitRFDLTNA1" = 'Size',
                      "FitRFDLATNA1" = 'Size'
                      
                      
         ),
         #output="data.frame",
         title = "Decreasing Return to Scale: The Role of ESG",
         notes="t-statistic appear in parenthis (). ALL explanatory variables are lagged one period"
)



