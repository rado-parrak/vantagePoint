'''
Created on Apr 18, 2018

@author: cloudera
'''
from pyspark.ml import Pipeline
from featureGenerator.customTransformers.Transformers import *

def constructPipeline(pipelineDef, inputCol):    
    stagess = []
    
    trans = {}    
    for key in sorted(pipelineDef):
        if pipelineDef[key][1] == 'root':
            toEval = "t_"+str(key)+" = "+pipelineDef[key][0]+"(inputCol = '"+inputCol+"', outputCol = '"+pipelineDef[key][2]+inputCol+"')"
        else: 
            toEval = "t_"+str(key)+" = "+pipelineDef[key][0]+"(inputCol = '"+pipelineDef[key][1]+inputCol+"', outputCol = '"+pipelineDef[key][2]+inputCol+"')"
        exec(toEval)
        
    stagess.extend(value for name, value in sorted(locals().items(), key=lambda item: item[0]) if name.startswith('t_'))
    return(Pipeline(stages = stagess))