'''
@author: Rado
'''
# DEPENDENCIES:
from utils import tools
from utils.hardcodedvariables import configuration
from featureGenerator.FeatureGenerator import *
from datetime import datetime
from pyspark.sql.functions import unix_timestamp
from pyspark.sql.functions import from_unixtime
from pyspark.sql.functions import desc


spark = tools.makeConnection("featureGeneration")

# read parquet
inputDf = tools.elapsedTime("READING RAW INPUT: ", spark.read.parquet, configuration.uploadedInput)

# cast into correct data types
for i in range(1,len(inputDf.columns)-2):
    colName = inputDf.columns[i]
    print("Casting column: " + colName)
    inputDf = inputDf.withColumn(colName, inputDf[colName].cast('float').alias(colName))
    
# cast 'snapshotDate' into timestamp
inputDf = inputDf.withColumn("snapshotDate_str", inputDf.snapshotDate).withColumn('snapshotDate', from_unixtime(unix_timestamp('snapshotDate_str', 'yyyy-MM-dd')).alias('snapshotDate')).drop("snapshotDate_str")

# sort by ID, desc(snapshotID):
inputDf = inputDf.orderBy('ID', desc("snapshotDate"))

import pandas
import numpy as np
from libs.utils.tools import ECDF

inputDfpd = inputDf.select('snapshotDate','AGE').toPandas().set_index('snapshotDate')
inputDfpd['E'] = inputDfpd['AGE'].groupby(inputDfpd.index).transform(lambda x: ECDF(x).getEcdf(None, None))
  
# plotting:
import matplotlib.pyplot as plt
from pylab import *

plotDf = inputDfpd.ix['2017-01-01 00:00:00']
show(plt.scatter(x = plotDf['AGE'], y = plotDf['E']))

# get rid of the original column
inputDfpd = inputDfpd.filter(axis = 1, items = ['E'])
inputDfpd = inputDfpd.reset_index()

# bucketing

from pyspark.ml.feature import Bucketizer
auxDf = tools.spark.createDataFrame(inputDfpd)    
splits = [-float("inf"), 0, 0.25, 0.5, 0.75, 1.0 ,float("inf")]
bucketizer = Bucketizer(splits=splits, inputCol="E", outputCol="B4_AGE")

# Transform original data into its bucket index.
auxDf = bucketizer.transform(auxDf)

print("Bucketizer output with %d buckets" % (len(bucketizer.getSplits())-1))
bucketedData.show()

from scipy.stats import norm
norm.ppf(0.95)
