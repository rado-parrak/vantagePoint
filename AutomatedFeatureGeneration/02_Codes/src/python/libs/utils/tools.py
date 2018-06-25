import os
import time
import hashlib
from pyspark.sql import SparkSession
from pyspark.conf import SparkConf
import numpy as np

def printEnv():
    print("****************************************************************************")
    for i in os.environ:
        print(i + " : " +  os.environ.get(i))
    print("****************************************************************************")

def makeConnection(appName):
#        .set("spark.executor.instances", "10") 
#        .set("spark.executor.memory", "500MB") 
#        .set("spark.executor.cores", "10") 
    sparkconfig= SparkConf() \
        .set("spark.debug.maxToStringFields", "1000") 
    sparksession = SparkSession \
        .builder \
        .config(conf=sparkconfig) \
        .appName(appName) \
        .getOrCreate()
    #sparksession.conf.set("spark.debug.maxToStringFields", "1000") 
    return sparksession

spark = makeConnection("featureGeneration")   
    
def printConfiguration(sparkSession):
    for i in sparkSession.sparkContext.getConf().getAll(): print(i)

def elapsedTime(comment,func, *args, **kwargs):
    start=time.time()
    retval=func(*args, **kwargs)
    print(comment +" : "+ (time.time()-start).__str__())
    return retval

def makeHash(string2hash):
    return hashlib.sha1(string2hash).hexdigest()

class ECDF:
    """
    One-dimensional empirical distribution function given a vector of
    observations.
    Parameters
    ----------
    observations : array_like
        An array of observations
    Attributes
    ----------
    observations : see Parameters
    """

    def __init__(self, observations):
        self.observations = np.asarray(observations)

    def __repr__(self):
        return self.__str__()

    def __str__(self):
        m = "Empirical CDF:\n  - number of observations: {n}"
        return m.format(n=self.observations.size)

    def __call__(self, x):
        """
        Evaluates the ecdf at x
        Parameters
        ----------
        x : scalar(float)
            The x at which the ecdf is evaluated
        Returns
        -------
        scalar(float)
            Fraction of the sample less than x
        """
        return np.mean(self.observations <= x)
    
    def getEcdf(self, a=None, b=None):
        """
        Plot the ecdf on the interval [a, b].
        Parameters
        ----------
        a : scalar(float), optional(default=None)
        Lower end point of the plot interval
        b : scalar(float), optional(default=None)
        Upper end point of the plot interval
        """
        # === choose reasonable interval if [a, b] not specified === #
        if a is None:
            a = self.observations.min() - self.observations.std()
        if b is None:
            b = self.observations.max() + self.observations.std()
        # === generate plot === #
        f = np.vectorize(self.__call__)
        return(f(self.observations))

    
