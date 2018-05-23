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

# read parquet
inputDf = tools.elapsedTime("READING RAW INPUT: ", tools.spark.read.parquet, configuration.uploadedInput)

# cast into correct data types
for i in range(1,len(inputDf.columns)-2):
    colName = inputDf.columns[i]
    print("Casting column: " + colName)
    inputDf = inputDf.withColumn(colName, inputDf[colName].cast('float').alias(colName))
    
# cast 'snapshotDate' into timestamp
inputDf = inputDf.withColumn("snapshotDate_str", inputDf.snapshotDate).withColumn('snapshotDate', from_unixtime(unix_timestamp('snapshotDate_str', 'yyyy-MM-dd')).alias('snapshotDate')).drop("snapshotDate_str")

# sort by ID, desc(snapshotID):
inputDf = inputDf.orderBy('ID', desc("snapshotDate"))

# do feature generation for all columns:
colsToFeatures = [x for x in inputDf.columns if x != 'ID']
colsToFeatures = [x for x in colsToFeatures if x != 'snapshotDate']

container = inputDf.select('snapshotDate', 'ID')

for colLabel in colsToFeatures:
    
    print(datetime.now().strftime('%Y-%m-%d %H:%M:%S') + '| Generating features for column: ' + colLabel)

    fg = FeatureGenerator(inputDf, colLabel, 'ID', 'snapshotDate')
    fg.generate()
    container = fg.mergeWithContainer(container)
    del fg
    
print('Feature generation done!')
container.printSchema()
container.orderBy('ID',desc('snapshotDate')).show(20)


    
