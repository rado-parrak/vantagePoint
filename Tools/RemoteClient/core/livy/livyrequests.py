'''
Created on Jun 17, 2018

@author: packer
'''
import shutil
import uuid
from core.requesthandler import RequestHandler
from core.requestexception import RequestException

class LivyRequests(RequestHandler):
    '''
    RequestHandler specialized to livy (basic functionality of urunning/monitoring/killing batch jobs).
    '''
    __resourceroot="/batches/"

    def __init__(self, connectionDetails, webhdfsrequests):
        '''
        Constructor
        '''
        RequestHandler.__init__(self,connectionDetails)
        self.__webhdfsrequests=webhdfsrequests
        
    @staticmethod
    def handlerId():
        return "Livy"    
        
    def list(self): 
        r=self._get(self.__resourceroot+"/", paramdict={"user.name":self.getConnectionDetails().getUser()}, headerdict={"Content-Type": "application/json"})
        return r.json()["sessions"]
    
    def kill(self, batchid): 
        r=self._del(self.__resourceroot+"/"+batchid, paramdict={"user.name":self.getConnectionDetails().getUser()}, headerdict={"Content-Type": "application/json"})
        return r.json()

    def log(self, batchid): 
        r=self._get(self.__resourceroot+"/"+batchid+"/log", paramdict={"user.name":self.getConnectionDetails().getUser()}, headerdict={"Content-Type": "application/json"})
        return r.json()

    def submit(self,
               file=None,                    # File containing the application to execute     path (required)
               #proxyUser,                   # User to impersonate when running the job     string
               #className,                   # Application Java/Spark main class     string
               #args,                        # Command line arguments for the application     list of strings
               #jars,                        # jars to be used in this session     list of strings
               pyPackage=None,#pyFiles,      # Python files to be used in this session     list of strings
               #files,                       # files to be used in this session     list of strings
               driverMemory=None,            # Amount of memory to use for the driver process     string
               driverCores=None,             # Number of cores to use for the driver process     int
               executorMemory=None,          # Amount of memory to use per executor process     string
               executorCores=None,           # Number of cores to use for each executor     int
               numExecutors=None,            # Number of executors to launch for this session     int
               #archives,                    # Archives to be used in this session     List of string
               queue=None,                   # The name of the YARN queue to which submitted     string
               name=None,                    # The name of this session     string
               conf=None                     # Spark configuration properties     Map of key=val
            ):
        body={}
        uuidstr=str(uuid.uuid4())
        if file is None: 
            raise RequestException("Main file is not provided for the job.")
        else:
            self.__webhdfsrequests.upload(file, "modules/"+uuidstr+"/main.py")
            body.update({"file":"/user/"+self.getConnectionDetails().getUser()+"/modules/"+uuidstr+"/main.py"})
        body.update({"proxyUser":self.getConnectionDetails().getUser()})
        if driverMemory is not None: body.update({"driverMemory":driverMemory})
        if driverCores is not None: body.update({"driverCores":driverCores})
        if executorMemory is not None: body.update({"executorMemory":executorMemory})
        if executorCores is not None: body.update({"executorCores":executorCores})
        if numExecutors is not None: body.update({"numExecutors":numExecutors})
        if pyPackage is not None:
            shutil.make_archive(pyPackage+"/../module", 'zip', pyPackage+"/..")
            self.__webhdfsrequests.upload(pyPackage+"/../module.zip", "modules/"+uuidstr+"/module.zip")
            body.update({"pyFiles":["/user/"+self.getConnectionDetails().getUser()+"/modules/"+uuidstr+"/module.zip"]})
        if queue is not None: body.update({"queue":queue})
        if name is not None: body.update({"name":name})
        if conf is not None: body.update({"conf":conf})
        r=self._post(self.__resourceroot+"/", paramdict={"user.name":self.getConnectionDetails().getUser()}, headerdict={"Content-Type": "application/json"}, bodydict=body)
        return r.json()


