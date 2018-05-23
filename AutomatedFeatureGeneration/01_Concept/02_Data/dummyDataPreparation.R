# Preparator for dummy data, similar in size to that of Argenta
# Author: Radovan Parrak (CREDO Analytics)

setwd("R:/01_Analytics/AutomatedFeatureGeneration/01_Concept/02_Data")
rm(list = ls())
require(dplyr)


kaggleData <- read.table("UCI_Credit_Card.csv", header = T, sep = ",")

# 1) Maket it 300 columns
cnames <- colnames(kaggleData)
cnames <- cnames[2:length(cnames)]

nRound <- 11

data <- kaggleData
for(i in 1:nRound){
  
  aux <- kaggleData %>% dplyr::select(cnames)
  colnames(aux) <- paste0(cnames,"_", i)
  
  data <- cbind(data, aux)  
  
}

# 2) Maket it 1.2 rows
nRound <- 1
monthlyData <- data
for(i in 1:nRound){
  print(paste0("---- Round: ", i))
  monthlyData <- rbind(monthlyData, data)  
}

monthlyData <- dplyr::mutate(monthlyData, ID = seq(1, nrow(monthlyData)))

# 2) Make it 12 months
nMonths <- 1
startDate <- as.Date("2017-01-01")

# fullData <- NULL
# for(i in 1:nMonths){
#   print(paste0("---- Months: ", i))
#   fullData <- rbind(fullData, mutate(monthlyData, snapshotDate = startDate+(i-1)*30))
# }
# write.table(fullData, file = "dummyFeatureGenerationData.csv", sep = ",", row.names = F)

for(i in 1:nMonths){
  print(paste0("---- Months: ", i))
  aux <- mutate(monthlyData, snapshotDate = startDate+(i-1)*30)
  if(i == 1){
    write.table(aux, file = "dummyFeatureGenerationData.csv", sep = ",", row.names = F, append = F, col.names = T)  
  } else{
    write.table(aux, file = "dummyFeatureGenerationData.csv", sep = ",", row.names = F, append = T, col.names = F)
  }
  
}



print("Done!")

