'''
Created on Apr 10, 2018

@author: cloudera
'''

from pyspark.ml import Pipeline
from featureGenerator.customTransformers.Transformers import *
from featureGenerator.pipelineDefinitions import PipelineDefs
from featureGenerator.pipelineUtils import constructPipeline
from utils.hardcodedvariables import featureGenerationController

class FeatureGenerator(object):
    '''
    
    The main feature generation class
    '''

    def __init__(self, df, colName, ID, timeID):
        '''
        Constructor
        '''                
        self.colName = colName
        self.df = df
        self.ID = ID
        self.timeID = timeID
    
    def  generate(self):
        # 1. Isolate only the relevant column
        self.container = self.df.select(self.timeID, self.ID, self.colName)
        
        # 2. construct the pipeline and do the trigger the transformation
        pipeline        = constructPipeline(featureGenerationController.featureGenerationController[self.colName], self.colName).fit(self.container)
        self.container  = pipeline.transform(self.container)
        
    def mergeWithContainer(self, globalContainer):
        globalContainer = globalContainer.join(self.container, [self.ID, self.timeID], 'left')
        #globalContainer = globalContainer.withColumn(self.container)
        return(globalContainer)        
        
        