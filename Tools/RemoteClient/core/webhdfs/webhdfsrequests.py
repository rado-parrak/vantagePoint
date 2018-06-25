'''
Created on May 17, 2018

@author: banyai
'''
from core.requesthandler import RequestHandler
from requests.exceptions import HTTPError
import pprint


class WebHDFSRequests(RequestHandler):
    '''
    RequestHandler specialized to WebHDFS (basic functionality of uploading/downloading/listing/... files from/to/on HDFS).
    '''
    __resourceroot="/webhdfs/v1/user/"

    def __init__(self, connectionDetails):
        '''
        Constructor
        '''
        RequestHandler.__init__(self,connectionDetails)
        
    @staticmethod
    def handlerId():
        return "WebHDFS"    
        
    def list(self, path): # PROXYUSER
        try:
            r=self._get(self.__resourceroot+"/"+self.getConnectionDetails().getUser()+"/"+path, 
            #r=self._get(self.__resourceroot, 
                paramdict={"op":"LISTSTATUS","user.name":self.getConnectionDetails().getUser()}, #"user.name":self.getConnectionDetails().getUser(),"doas":"hadoop"}
                headerdict={"Content-Type": "application/json"}
            )
        except HTTPError as e:
            if e.response.status_code==404: return {}
            raise e
        l={}
        for i in r.json()["FileStatuses"]["FileStatus"]:
            l.update({i["pathSuffix"]:i})
        return l
    
    def upload(self, localfile, remotefile):
        # according to webhdfs docs this supposed to be a two-step procedure, but:
        #   1.: you can have a hdfs protocol url for location and request don't like it
        #   2.: functionality changed and you can put body into the create call and forwarding works automatically
        # TWO STEP LEGACY, JUST IN CASE:
        # r1=self._put(self.__resourceroot+remotefile, paramdict={"op":"CREATE","overwrite":"true","user.name":self.getConnectionDetails().getUser()})
        # desturl=r1.headers["Location"]
        # r2=self._raw("PUT", desturl, headerdict={"Content-Type":"application/octet-stream"}, rawbody=open(localfile,'rb'))
        # -----------------------
        #buffersize is 8kb as default configuration, maybe needed to be adjusted later
        # username!!!
        self._put(self.__resourceroot+"/"+self.getConnectionDetails().getUser()+"/"+remotefile, paramdict={"op":"CREATE","overwrite":"true","user.name":self.getConnectionDetails().getUser()}, headerdict={"Content-Type":"application/octet-stream"}, rawbody=open(localfile,'rb'))

    def download(self, remotefile, localfile):
        f=open(localfile,'wb')
        pos=0
        bs=1048576
        while True:
            #print("CHUNK: "+str(pos))
            r=self._get(self.__resourceroot+"/"+self.getConnectionDetails().getUser()+"/"+remotefile, paramdict={"op":"OPEN","user.name":self.getConnectionDetails().getUser(),"offset":pos,"length":bs}, headerdict={"Content-Type":"application/octet-stream"})
            f.write(bytes(r.content))
            l=len(r.content)
            if (l<bs): break
            pos+=l
        f.flush()
        f.close()

    def append(self, localfile, remotefile):
        self._post(self.__resourceroot+"/"+self.getConnectionDetails().getUser()+"/"+remotefile, paramdict={"op":"APPEND","user.name":self.getConnectionDetails().getUser(),"append":"true"}, headerdict={"Content-Type":"application/octet-stream"}, rawbody=open(localfile,'rb'))
        
    def delete(self, path):
        self._del(self.__resourceroot+"/"+self.getConnectionDetails().getUser()+"/"+path, paramdict={"op":"DELETE","user.name":self.getConnectionDetails().getUser(),"recursive":"true"}, headerdict={"Content-Type": "application/json"})
