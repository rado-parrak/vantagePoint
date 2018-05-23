'''
Created on Apr 17, 2018

@author: cloudera
'''

from pyspark import keyword_only  ## < 2.0 -> pyspark.ml.util.keyword_only
from pyspark.ml import Transformer
from pyspark.ml.param.shared import HasInputCol, HasOutputCol
from pyspark.sql.window import Window
import pyspark.sql.functions as F
import pandas
from utils import tools
import numpy as np
from libs.utils.tools import ECDF
from pyspark.ml.feature import Bucketizer, Binarizer
from scipy.stats import norm

class Cs_distanceFromMean(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_distanceFromMean, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def distanceFromMean(self, df, c):
        return(df[c] - df.groupBy('snapshotDate').agg(F.mean(df[c]).alias("mean")).collect()[0]["mean"])
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.withColumn(out_col, self.distanceFromMean(dataset, in_col))
    
class Cs_distanceFromMin(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_distanceFromMin, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def distanceFromMin(self, df, c):
        return(df[c] - df.groupBy('snapshotDate').agg(F.min(df[c]).alias("min")).collect()[0]["min"])
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.withColumn(out_col, self.distanceFromMin(dataset, in_col))
    
class Cs_distanceFromMax(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_distanceFromMax, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def distanceFromMax(self, df, c):
        return(df[c] - df.groupBy('snapshotDate').agg(F.max(df[c]).alias("max")).collect()[0]["max"])
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.withColumn(out_col, self.distanceFromMax(dataset, in_col))

class Cs_distanceFromMedian(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_distanceFromMedian, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def distanceFromMedian(self, df, c):
        # RADO: Pandas implementation since median not available in the Spark native functions
        auxPandasDf = df.select('snapshotDate',c).toPandas().groupby('snapshotDate').median().rename(index=str, columns={c: "MEDIAN_"+c})
        auxPandasDf.index.name = 'snapshotDate'
        auxPandasDf = auxPandasDf.reset_index()
        # cast to spark DataFrame
        auxDf = tools.spark.createDataFrame(auxPandasDf)
        df = df.join(auxDf, ['snapshotDate'], 'left')
        df = df.withColumn('DME_'+c, df[c] - df["MEDIAN_"+c]).select('ID','snapshotDate','DME_'+c)
                
        return(df)
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.join(self.distanceFromMedian(dataset, in_col), ['snapshotDate','ID'],'left')

class Cs_ecdf(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_ecdf, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def ecdf(self, df, c):        
        auxPandasDf = df.select('snapshotDate', 'ID',c).toPandas().set_index('snapshotDate')
        auxPandasDf['E_'+c] = auxPandasDf[c].groupby(auxPandasDf.index).transform(lambda x: ECDF(x).getEcdf(None, None))
        auxPandasDf = auxPandasDf.reset_index()      
        
        # cast to spark DataFrame
        auxDf = tools.spark.createDataFrame(auxPandasDf)                
        return( auxDf.select('snapshotDate','ID','E_'+c) )
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.join(self.ecdf(dataset, in_col), ['snapshotDate','ID'],'left')
    
class Cs_bucketize(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_bucketize, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def bucketize(self, df, c):   
        bucketizer4 = Bucketizer(splits=[-float("inf"), 0, 0.25, 0.5, 0.75, 1.0 ,float("inf")], inputCol=c, outputCol="B4_"+c) 
        bucketizer10 = Bucketizer(splits=[-float("inf"), 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0 ,float("inf")], inputCol=c, outputCol="B10_"+c)   
         
        df = bucketizer4.transform(df.select('snapshotDate','ID',c))
        df = bucketizer10.transform(df)
                         
        return( df.select('snapshotDate','ID','B4_'+c, 'B10_'+c) )
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        return dataset.join(self.bucketize(dataset, in_col), ['snapshotDate','ID'],'left')

class Cs_quantile(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_quantile, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def quantile(self, df, c):   
        auxPandasDf = df.select('snapshotDate', 'ID',c).toPandas().set_index('snapshotDate')
        auxPandasDf['Q_'+c] = norm.ppf(auxPandasDf[c])
        auxPandasDf = auxPandasDf.reset_index()      
        
        # cast to spark DataFrame
        auxDf = tools.spark.createDataFrame(auxPandasDf)                
        return( auxDf.select('snapshotDate','ID','Q_'+c) )
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        return dataset.join(self.quantile(dataset, in_col), ['snapshotDate','ID'],'left')

class Cs_naiveOutliers(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Cs_naiveOutliers, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def naiveOutliers(self, df, c):   
        binazer_2sdu = Binarizer(threshold = 2.0, inputCol=c, outputCol="2SDU_"+c)
        binazer_3sdu = Binarizer(threshold = 3.0, inputCol=c, outputCol="3SDU_"+c)
        binazer_2sdd = Binarizer(threshold = 2.0, inputCol=c, outputCol="2SDD_"+c)
        binazer_3sdd = Binarizer(threshold = 3.0, inputCol=c, outputCol="3SDD_"+c)   
         
        df = binazer_2sdu.transform(df.select('snapshotDate','ID',c))
        df = binazer_3sdu.transform(df)
        df = df.withColumn(c, -1.0 * df[c])
        df = binazer_2sdd.transform(df)
        df = binazer_3sdd.transform(df)
                         
        return( df.select('snapshotDate','ID','2SDU_'+c, '3SDU_'+c, '2SDD_'+c, '3SDD_'+c,) )
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        return dataset.join(self.naiveOutliers(dataset, in_col), ['snapshotDate','ID'],'left')

class Ts_distanceFromMovingAverages(Transformer, HasInputCol, HasOutputCol):    
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Ts_distanceFromMovingAverages, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def distanceFromMovingMean(self, df, c, n):
        wSpec1 = Window.partitionBy('ID').orderBy('ID',F.desc('snapshotDate')).rowsBetween(0, n)        
        return(df[c] - F.avg(df[c]).over(wSpec1))
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.withColumn(out_col+'_2', self.distanceFromMovingMean(dataset, in_col, 2))\
            .withColumn(out_col+'_3', self.distanceFromMovingMean(dataset, in_col, 3))\
            .withColumn(out_col+'_6', self.distanceFromMovingMean(dataset, in_col, 6))
            
class Ts_distanceFromMovingMaxs(Transformer, HasInputCol, HasOutputCol):    
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Ts_distanceFromMovingMaxs, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def distanceFromMovingMax(self, df, c, n):
        wSpec1 = Window.partitionBy('ID').orderBy('ID',F.desc('snapshotDate')).rowsBetween(0, n)        
        return(df[c] - F.max(df[c]).over(wSpec1))
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.withColumn(out_col+'_2', self.distanceFromMovingMax(dataset, in_col, 2))\
            .withColumn(out_col+'_3', self.distanceFromMovingMax(dataset, in_col, 3))\
            .withColumn(out_col+'_6', self.distanceFromMovingMax(dataset, in_col, 6))
            
class Ts_distanceFromMovingMins(Transformer, HasInputCol, HasOutputCol):    
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Ts_distanceFromMovingMins, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def distanceFromMovingMin(self, df, c, n):
        wSpec1 = Window.partitionBy('ID').orderBy('ID',F.desc('snapshotDate')).rowsBetween(0, n)        
        return(df[c] - F.min(df[c]).over(wSpec1))
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        out_col = self.getOutputCol()
        return dataset.withColumn(out_col+'_2', self.distanceFromMovingMin(dataset, in_col, 2))\
            .withColumn(out_col+'_3', self.distanceFromMovingMin(dataset, in_col, 3))\
            .withColumn(out_col+'_6', self.distanceFromMovingMin(dataset, in_col, 6))
            
class Ts_lags(Transformer, HasInputCol, HasOutputCol):    
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(Ts_lags, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def lags(self, df, c):
        
        windowAggregator = Window.partitionBy("ID").orderBy("ID")

        df = df.select("snapshotDate", "ID", c)
        df = df.withColumn("L1_"+ c, F.lag(df[c], count = -1).over(windowAggregator))
        df = df.withColumn("L2_"+ c, F.lag(df[c], count = -2).over(windowAggregator))
        df = df.withColumn("L3_"+ c, F.lag(df[c], count = -3).over(windowAggregator))
        df = df.withColumn("L6_"+ c, F.lag(df[c], count = -6).over(windowAggregator))  

        return(df.select('snapshotDate', 'ID', "L1_"+ c, "L2_"+ c, "L3_"+ c, "L6_"+ c))
    
    def _transform(self, dataset):
        in_col  = self.getInputCol()
        return dataset.join(self.lags(dataset, in_col), ['snapshotDate','ID'],'left')

class doNothing(Transformer, HasInputCol, HasOutputCol):
    @keyword_only
    def __init__(self, inputCol=None, outputCol=None):
        super(doNothing, self).__init__()
        kwargs = self._input_kwargs
        self.setParams(**kwargs)

    @keyword_only
    def setParams(self, inputCol=None, outputCol=None):
        kwargs = self._input_kwargs
        return self._set(**kwargs)
    
    def _transform(self, dataset):
        return dataset
        