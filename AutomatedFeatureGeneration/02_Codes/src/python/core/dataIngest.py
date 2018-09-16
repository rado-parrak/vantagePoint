from utils import tools
from utils.hardcodedvariables import configuration
from utils.tools import elapsedTime
from datetime import datetime
import time

print "001__MEASURE__ START(overall time): %s %.3f" % (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),time.time())

# submission entry point
spark = tools.makeConnection("dataIngest")

#read in an elapsedtime wrapper
print "002__MEASURE__ START(reading from hdfs as csv): %s %.3f" % (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),time.time())
df = elapsedTime("READING IN CSV", spark.read.csv, configuration.localInput,header="true")
print "002__MEASURE__ STOP: %s %.3f" % (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),time.time())

# the dot in column generates problems because spark supports nested structures (where subfields are accessed by standard 'parent.field' syntax) 
#   -> replacing all dots in all names with underscores
cols=[]
for i in df.columns: cols.append(i.replace(".","_"))
df=df.toDF(*cols)

# info
print "SIZE: "+str(df.count())
df.show()
df.printSchema()

# write it to hdfs
print "003__MEASURE__ START(saving to hdfs as parquet): %s %.3f" % (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),time.time())
elapsedTime("SAVING TO PARQUET IN HDFS", df.write.mode("overwrite").parquet, configuration.uploadedInput)
print "003__MEASURE__ STOP: %s %.3f" % (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),time.time())

# spark.close()
print "REACHED THE END"
print "001__MEASURE__ STOP: %s %.3f" % (datetime.now().strftime('%Y-%m-%d %H:%M:%S'),time.time())

