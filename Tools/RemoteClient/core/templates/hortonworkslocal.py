'''
Created on May 16, 2018
@author: banyai
'''
import os
from core.handlertemplate import HandlerTemplate
from core.webhdfs.webhdfsrequests import WebHDFSRequests
from core.connectiondetails import ConnectionDetails
from core.livy.livyrequests import LivyRequests


class HortonWorksLocal(HandlerTemplate):
    '''
    HortonWorks Hadoop cluster running in a local virtualbox machine.
    @TODO: expose ip, port and user as named argument in constructor
    '''

    def __init__(self, user=os.environ["USER"], authtpl=None):
        '''
        Constructor
        '''
        HandlerTemplate.__init__(self)
        
        self.addConnectionHandler(WebHDFSRequests(ConnectionDetails("http","172.17.0.2","50070",user,authtpl)\
            .addHeader({
                "X-Requested-By": user, 
                "Content-Encoding": "gzip", 
                "Transfer-Encoding": "gzip"
            })\
#            .addParam({
#                "user.name": user
#            })\
        ))

        self.addConnectionHandler(LivyRequests(ConnectionDetails("http","172.17.0.2","8999",user,authtpl)\
            .addHeader({
                "X-Requested-By": user, 
                "Content-Encoding": "gzip", 
                "Transfer-Encoding": "gzip"
            })\
#            .addParam({
#                "user.name": user
#            })\
        ,self.getWebHDFSHandler()))

                
#         self.addConnectionDetails("livy", ConnectionDetails(None,"172.17.0.2","8999")\
#             .addHeader({ 
#                 "X-Requested-By": user, 
#                 "Content-Type": "application/json",
#                 "Content-Encoding": "gzip", 
#                 "Transfer-Encoding": "gzip"
#             })\
#             .addBody({ 
#                 "proxyUser": user 
#             }))
#         self.addConnectionDetails("webhdfs", ConnectionDetails(HDFSRequests(),"172.17.0.2","50070")\
#             .addHeader({
#                 "X-Requested-By": user, 
#                 "Content-Type": "application/json",
#                 "Content-Encoding": "gzip", 
#                 "Transfer-Encoding": "gzip"
#             })\
#             .addBody({ 
#                 "proxyUser": user 
#             }))
         

#     def getWebHDFSRequests(self):
#         return HDFSRequests
 