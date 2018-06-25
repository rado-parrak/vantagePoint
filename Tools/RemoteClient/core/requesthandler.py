'''
Created on May 17, 2018

@author: banyai
'''
import requests
from core.connectiondetails import ConnectionDetails
from core.requestexception import RequestException
from pprint import pprint
from requests.sessions import Session
from requests.models import Request

class RequestHandler(object):
    '''
    Is a general request handler that serves all specific implementations by simply changing the resurce dir and the additional options.
    Every new implementations should 'register' in HandlerTemplate
    '''

    def __init__(self, connectionDetails):
        '''
        Constructor
        '''
        if not isinstance(connectionDetails, ConnectionDetails):
            raise RequestException("Connection detail is not actually derived from Connectiondetails.")
        self.__connectionDetails=connectionDetails      
        self.debug=False
        self.session=Session()
        
    def handlerId(self): raise RequestException("handlerId() is not overridden in specialization: "+self.__class__+", please implement it as a static method.")    

    def _raw(self, mode, url, headerdict=None, paramdict=None, bodydict=None, rawbody=None):
        if (bodydict is not None) and (rawbody is not None):
            raise RequestException("Not allowed to specify dictionary and raw body at the same time.")
        try:
            pr=self.session.prepare_request(Request(mode, url, headers=headerdict, params=paramdict, data=rawbody, json=bodydict, auth=self.__connectionDetails.getAuth()))
            if self.debug: pprint(vars(pr), indent=2, depth=100)
            r=self.session.send(pr)
            if self.debug: pprint(vars(r), indent=2, depth=100)
            r.raise_for_status()
        except requests.RequestException as e:
            e.args=e.args[0:]+(e.response.content,)
            raise e
        return r
          
    def _post(self, resource, headerdict=None, paramdict=None, bodydict=None, rawbody=None):
        if (bodydict is not None) and (rawbody is not None):
            raise RequestException("Not allowed to specify dictionary and raw body at the same time.")
        h={}
        b={}
        p={}
        if self.__connectionDetails is None: raise RequestException("Connection detail is None.")
        h.update(self.__connectionDetails.getHeader())
        b.update(self.__connectionDetails.getBody())
        p.update(self.__connectionDetails.getParam())
        if headerdict is not None: h.update(headerdict)
        if bodydict is not None: b.update(bodydict)
        if paramdict is not None: p.update(paramdict)
        if len(h) is 0: h=None
        if len(b) is 0: b=None
        if len(p) is 0: p=None
        try:
            if (rawbody is not None):
                # ignoring template-default body parameters!!!
                pr=self.session.prepare_request(Request("POST",self.__connectionDetails.formURL()+self._formatResource(resource), headers=h, params=p, data=rawbody, auth=self.__connectionDetails.getAuth()))
            else:
                pr=self.session.prepare_request(Request("POST",self.__connectionDetails.formURL()+self._formatResource(resource), headers=h, params=p, json=b, auth=self.__connectionDetails.getAuth()))
            if self.debug: pprint(vars(pr), indent=2, depth=100)
            r=self.session.send(pr)
            if self.debug: pprint(vars(r), indent=2, depth=100)
            r.raise_for_status()
        except Exception as e:
            e.args=e.args[0:]+(e.response.content,)
            raise e
        return r
        
    def _put(self, resource, headerdict=None, paramdict=None, bodydict=None, rawbody=None):
        if (bodydict is not None) and (rawbody is not None):
            raise RequestException("Not allowed to specify dictionary and raw body at the same time.")
        h={}
        b={}
        p={}
        if self.__connectionDetails is None: raise RequestException("Connection detail is None.")
        h.update(self.__connectionDetails.getHeader())
        b.update(self.__connectionDetails.getBody())
        p.update(self.__connectionDetails.getParam())
        if headerdict is not None: h.update(headerdict)
        if bodydict is not None: b.update(bodydict)
        if paramdict is not None: p.update(paramdict)
        if len(h) is 0: h=None
        if len(b) is 0: b=None
        if len(p) is 0: p=None
        try:
            if (rawbody is not None):
                # ignoring template-default body parameters!!!
                pr=self.session.prepare_request(Request("PUT",self.__connectionDetails.formURL()+self._formatResource(resource), headers=h, params=p, data=rawbody, auth=self.__connectionDetails.getAuth()))
            else:
                pr=self.session.prepare_request(Request("PUT",self.__connectionDetails.formURL()+self._formatResource(resource), headers=h, params=p, json=b, auth=self.__connectionDetails.getAuth()))
            if self.debug: pprint(vars(pr), indent=2, depth=100)
            r=self.session.send(pr)
            if self.debug: pprint(vars(r), indent=2, depth=100)
            r.raise_for_status()
        except requests.RequestException as e:
            e.args=e.args[0:]+(e.response.content,)
            raise e
        return r

    def _get(self, resource, headerdict=None, paramdict=None):
        # attaching body is highly discouraged, therefore not supported
        h={}
        p={}
        if self.__connectionDetails is None: raise RequestException("Connection detail is None.")
        h.update(self.__connectionDetails.getHeader())
        p.update(self.__connectionDetails.getParam())
        if headerdict is not None: h.update(headerdict)
        if paramdict is not None: p.update(paramdict)
        if len(h) is 0: h=None
        if len(p) is 0: p=None
        try:
            pr=self.session.prepare_request(Request("GET",self.__connectionDetails.formURL()+self._formatResource(resource),  params=p, headers=h, auth=self.__connectionDetails.getAuth()))
            if self.debug: pprint(vars(pr), indent=2, depth=100)
            r=self.session.send(pr)
            if self.debug: pprint(vars(r), indent=2, depth=100)
            r.raise_for_status()
        except requests.RequestException as e:
            e.args=e.args[0:]+(e.response.content,)
            raise e
        return r
    
    def _del(self, resource, headerdict=None, paramdict=None):
        # attaching body is highly discouraged, therefore not supported
        h={}
        p={}
        if self.__connectionDetails is None: raise RequestException("Connection detail is None.")
        h.update(self.__connectionDetails.getHeader())
        p.update(self.__connectionDetails.getParam())
        if headerdict is not None: h.update(headerdict)
        if paramdict is not None: p.update(paramdict)
        if len(h) is 0: h=None
        if len(p) is 0: p=None
        try:
            pr=self.session.prepare_request(Request("DELETE",self.__connectionDetails.formURL()+self._formatResource(resource),  params=p, headers=h, auth=self.__connectionDetails.getAuth()))
            if self.debug: pprint(vars(pr), indent=2, depth=100)
            r=self.session.send(pr)
            if self.debug: pprint(vars(r), indent=2, depth=100)
            r.raise_for_status()
        except Exception as e:
            e.args=e.args[0:]+(e.response.content,)
            raise e
        return r
      
    def getConnectionDetails(self):
        return self.__connectionDetails
    
    def _formatResource(self,*args):
        r=""
        if args is None: return r
        for i in args: r+="/"+i
        return r.replace("\\", "/").replace("///", "/").replace("//", "/")
    
        
    
    
    
    