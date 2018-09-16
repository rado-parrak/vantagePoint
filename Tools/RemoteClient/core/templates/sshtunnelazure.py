'''
Created on Jun 22, 2018

@author: banyai
'''

import os
from core.handlertemplate import HandlerTemplate
from core.connectiondetails import ConnectionDetails
from core.livy.livyrequests import LivyRequests
from core.webhdfs.sshhdfs import SSHHDFS


class TunnelSSHAzure(HandlerTemplate):
    '''
    Azure HDInsight cluster with tunneled access on ports 8081-livy and 8082-webhdfs.
    @TODO: expose ip, port and user as named argument in constructor
    '''

    def __init__(self, user=os.environ["USER"], authtpl=None):
        '''
        Constructor
        '''
        HandlerTemplate.__init__(self)
        
        self.addConnectionHandler(SSHHDFS(ConnectionDetails("http","localhost","8902",user,authtpl)\
            .addHeader({
                "X-Requested-By": user, 
#                "Content-Encoding": "gzip", 
#                "Transfer-Encoding": "gzip"
            })\
#            .addParam({
#                "user.name": user
#            })\
        ))
        
        self.addConnectionHandler(LivyRequests(ConnectionDetails("http","localhost","8900",user,authtpl)\
            .addHeader({
                "X-Requested-By": user, 
#                "Content-Encoding": "gzip", 
#                "Transfer-Encoding": "gzip"
            })\
#            .addParam({
#                "user.name": user
#            })\
        ,self.getWebHDFSHandler()))        
        

        