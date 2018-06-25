'''
Created on May 16, 2018
@author: banyai
'''
import os
from core.handlertemplate import HandlerTemplate
from core.webhdfs.webhdfsrequests import WebHDFSRequests
from core.connectiondetails import ConnectionDetails
from core.livy.livyrequests import LivyRequests


class AzureHDInsight(HandlerTemplate):
    '''
    Azure HDInsight cluster running in a local virtualbox machine.
    @TODO: expose ip, port and user as named argument in constructor
    '''

    def __init__(self, user=os.environ["USER"], authtpl=None):
        '''
        Constructor
        '''
        HandlerTemplate.__init__(self)
        
        self.addConnectionHandler(WebHDFSRequests(ConnectionDetails("https","credo-test-hdinsight.azurehdinsight.net","443",user,authtpl)\
            .addHeader({
                "X-Requested-By": user, 
#                "Content-Encoding": "gzip", 
#                "Transfer-Encoding": "gzip"
            })\
#            .addParam({
#                "user.name": user
#            })\
        ))
        
        self.addConnectionHandler(LivyRequests(ConnectionDetails("https","credo-test-hdinsight.azurehdinsight.net","443/livy",user,authtpl)\
            .addHeader({
                "X-Requested-By": user, 
#                "Content-Encoding": "gzip", 
#                "Transfer-Encoding": "gzip"
            })\
#            .addParam({
#                "user.name": user
#            })\
        ,self.getWebHDFSHandler()))        
        
        
        
        
        