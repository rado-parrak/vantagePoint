'''
Created on May 16, 2018
@author: banyai
'''
from core.requestexception import RequestException
from core.requesthandler import RequestHandler
from core.webhdfs.webhdfsrequests import WebHDFSRequests
from core.livy.livyrequests import LivyRequests


class HandlerTemplate(object):
    '''
    This is a collector class for all the different web services that a code might use.
    The specialized templates must derive from this class.
    @TODO extend the helpers with providing more options
    '''

    def __init__(self):
        '''
        Constructor
        '''
        self.__handlerdict={}
        
    def addConnectionHandler(self, connectionHandler):
        if connectionHandler.handlerId() in self.__handlerdict:
            raise RequestException("Connection handler: "+connectionHandler.handlerId()+" already exists.")
        if not isinstance(connectionHandler, RequestHandler):
            raise RequestException("Connection handler: "+connectionHandler.__class__+" is not derived from RequestHandler.")
        self.__handlerdict[connectionHandler.handlerId()]=connectionHandler
    
    def __getConnectionHandler(self, connectionIdStr):
        if connectionIdStr not in self.__handlerdict:
            raise RequestException("Connection handler: "+connectionIdStr+" not found.")
        return self.__handlerdict[connectionIdStr]
        
    # shorthands for the individual services, may or may not be implemented
    def getWebHDFSHandler(self): return self.__getConnectionHandler(WebHDFSRequests.handlerId())
    def getLivyHandler(self): return self.__getConnectionHandler(LivyRequests.handlerId())
    
    # general helpers to modify handler/connection details at once for all handlers
    def setUser(self, userstr):
        for i in self.__handlerdict.values():
            i.getConnectionDetails.setUser(userstr)
    
    def setAuth(self, authtpl):
        for i in self.__handlerdict.values():
            i.getConnectionDetails.setAuth(authtpl)
    
    
    
    