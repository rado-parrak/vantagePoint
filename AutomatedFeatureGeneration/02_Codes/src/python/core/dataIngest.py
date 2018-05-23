from utils import tools
from utils.hardcodedvariables import configuration
from utils.tools import elapsedTime

# submission entry point
spark = tools.makeConnection("dataIngest")

#read in an elapsedtime wrapper
df = elapsedTime("READING IN CSV", spark.read.csv, configuration.localInput,header="true")

# the dot in column generates problems because spark supports nested structures (where subfields are accessed by standard 'parent.field' syntax) 
#   -> replacing all dots in all names with underscores
cols=[]
for i in df.columns: cols.append(i.replace(".","_"))
df=df.toDF(*cols)

# info
print("SIZE: "+ str(df.count()))
df.show()
df.printSchema()

# write it to hdfs
elapsedTime("SAVING TO PARQUET IN HDFS", df.write.mode("overwrite").parquet, configuration.uploadedInput)
