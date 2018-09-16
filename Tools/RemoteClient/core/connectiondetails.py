'''
Created on May 16, 2018
@author: banyai
'''
import os

class ConnectionDetails(object):
    '''
    This class holds the data of the connection. 
    '''

    def __init__(self, protocolstr, hoststr, portstr, userstr, authtpl):
        '''
        Constructor
        '''
        self.__protocol=None
        self.__host=None
        self.__port=None
        self.__header={}
        self.__body={}
        self.__param={}
        self.__auth=None
        self.__user=None
        self.setProtocol(protocolstr)
        self.setHost(hoststr)
        self.setPort(portstr)
        self.setAuth(authtpl)
        self.setUser(userstr)
        
    def setProtocol(self, protocolstr):
        self.__protocol=protocolstr
        return self

    def setHost(self, hoststr):
        self.__host=hoststr
        return self
    
    def setPort(self, portstr):
        self.__port=portstr
        return self   
        
    def setUser(self, userstr):
        self.__user=userstr if userstr is not None else os.environ["USER"]
        return self   

    def setAuth(self, authtpl):
        self.__auth=authtpl
        return self   
        
    def addHeader(self, headerdict):
        self.__header.update(headerdict)
        return self
        
    def addBody(self, bodydict):
        self.__body.update(bodydict)
        return self
    
    def addParam(self, paramdict):
        self.__param.update(paramdict)
        return self

    def formURL(self):
        return self.__protocol+"://"+self.__host+":"+self.__port

    def getHost(self):
        return self.__host
        
    def getPort(self):
        return self.__port

    def getHeader(self):
        return self.__header
        
    def getBody(self):
        return self.__body
    
    def getParam(self):
        return self.__param
        
    def getAuth(self):
        return self.__auth
    
    def getUser(self):
        return self.__user
    