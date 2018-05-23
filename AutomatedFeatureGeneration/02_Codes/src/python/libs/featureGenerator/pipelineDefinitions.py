'''
Created on Apr 18, 2018

@author: cloudera
'''

class PipelineDefs(object):
    '''
    classdocs
    '''
    pipeline_0 = {0:['doNothing', 'whatever', 'whatever']} # default pipeline
    pipeline_1 = {
                    0:['Cs_distanceFromMean', 'root', 'DM_']
                  , 1:['Cs_distanceFromMin', 'root',"DMI_"]
                  , 2:['Cs_distanceFromMax', 'root',"DMA_"]
                  , 3:['Cs_distanceFromMedian','root',"DME_"]
                  , 4:['Cs_ecdf', 'root', 'E_']
                  , 5:['Cs_bucketize', 'E_', 'whatever']
                  , 6:['Cs_quantile', 'E_', 'Q_E_']
                  , 7:['Cs_naiveOutliers', 'Q_E_', 'whatever']
                  , 8:['Ts_distanceFromMovingAverages', 'root', "DMM_"]
                  , 9:['Ts_distanceFromMovingMins', 'root', "DMMI_"]
                  , 10:['Ts_distanceFromMovingMaxs', 'root', "DMMA_"]
                  , 11:['Ts_lags', 'root',"whatever"] 
                  , 12:['Ts_lags', 'DM_',"whatever"]
                  }

    def __init__(self, params):
        '''
        Constructor
        '''
    