from utils import tools
from utils.hardcodedvariables import configuration
from featureGenerator.FeatureGenerator import FeatureGenerator 
from datetime import datetime
from pyspark.sql.functions import *
from pyspark.ml import Pipeline
from featureGenerator.customTransformers.Transformers import *


spark = tools.makeConnection("scrapsheetConnection")

# read parquet
inputDf = tools.elapsedTime("READING RAW INPUT: ", spark.read.parquet, configuration.uploadedInput)

# cast into correct data types
for i in range(1,len(inputDf.columns)-2):
    colName = inputDf.columns[i]
    print("Casting column: " + colName)
    inputDf = inputDf.withColumn(colName, inputDf[colName].cast('float').alias(colName))

inputDf = inputDf.select('snapshotDate','ID','AGE')
inputDf.show()

t1 = Cs_distanceFromMean(inputCol = 'AGE', outputCol = 'DM_AGE')
t2 = Cs_distanceFromMin(inputCol = 'AGE', outputCol = 'DMI_AGE')
t3 = Cs_distanceFromMax(inputCol = 'AGE', outputCol = 'DMA_AGE')

pipeline = Pipeline(stages=[t1,t2,t3])
model=pipeline.fit(inputDf)
train2=model.transform(inputDf)
train2.show()

