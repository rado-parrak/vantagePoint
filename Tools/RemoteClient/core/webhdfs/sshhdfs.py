'''
Created on Jun 22, 2018

@author: banyai
'''

from core.requesthandler import RequestHandler
import paramiko
from core.requestexception import RequestException
from builtins import Exception
from time import sleep
import io

class SSHHDFS(RequestHandler):
    
    def __init__(self, connectionDetails):
        '''
        Constructor
        '''
        RequestHandler.__init__(self,connectionDetails)
        self.__client=paramiko.SSHClient()
        self.__client.load_system_host_keys()
        self.__client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

        
    @staticmethod
    def handlerId():
        return "WebHDFS"    

    def __waittofinsih(self, ssh_stdin, ssh_stdout, ssh_stderr, stdout_tofile=None):
        if stdout_tofile is not None: f=open(stdout_tofile, "wb", buffering=1048576)
        outdata=bytes()
        errdata=bytes()
        ssh_stdin.flush()
        ssh_stdin.channel.shutdown_write()
        while True:  # monitoring process
            while ssh_stdout.channel.recv_ready():
                ssh_stdout.flush()
                outdata += ssh_stdout.channel.recv(ssh_stdout._bufsize)
            while ssh_stderr.channel.recv_stderr_ready():
                ssh_stderr.flush()
                errdata += ssh_stderr.channel.recv_stderr(ssh_stderr._bufsize)
            if stdout_tofile is not None: 
                f.write(bytes(outdata))
                outdata=bytes()
            if ssh_stdout.channel.exit_status_ready() and ssh_stderr.channel.exit_status_ready():
                break
            sleep(0.001)
        ssh_stdout.flush()
        outdata += ssh_stdout.channel.recv(ssh_stdout._bufsize)
        ssh_stderr.flush()
        errdata += ssh_stderr.channel.recv_stderr(ssh_stderr._bufsize)
        if stdout_tofile is not None: 
            f.write(bytes(outdata))
            outdata=bytes()
            f.flush()
            f.close()
        if ssh_stdout.channel.recv_exit_status() is not 0: raise RequestException({"stdout":outdata,"stderr":errdata})
        return outdata

    def list(self, path): # PROXYUSER
        try:
            self.__client.connect(hostname=self.getConnectionDetails().getHost(), port=self.getConnectionDetails().getPort(), username=self.getConnectionDetails().getAuth()[0], password=self.getConnectionDetails().getAuth()[1], compress=True)
            ssh_stdin, ssh_stdout, ssh_stderr = self.__client.exec_command("hdfs dfs -ls -C "+self._formatResource("/user/"+self.getConnectionDetails().getUser()+"/"+path))
            out=self.__waittofinsih(ssh_stdin, ssh_stdout, ssh_stderr)
            self.__client.close()
        except Exception as e:
            self.__client.close()
            raise e
        r={}
        for i in out.decode("utf-8").strip("\n").split("\n"):
            if len(i)>0: r.update({i:{"msg":"Detail functionality is turned off for now."}})
        return r
        
    def upload(self, localfile, remotefile):
        try:
            self.__client.connect(hostname=self.getConnectionDetails().getHost(), port=self.getConnectionDetails().getPort(), username=self.getConnectionDetails().getAuth()[0], password=self.getConnectionDetails().getAuth()[1], compress=True)            
            ssh_stdin, ssh_stdout, ssh_stderr = self.__client.exec_command("hdfs dfs -put -f - "+self._formatResource("/user/"+self.getConnectionDetails().getUser()+"/"+remotefile))
            f=open(localfile,'rb')
            ssh_stdin.flush()
            while True:
                if ssh_stdin.closed:
                    raise RequestException("Input channel is closed.") 
                if ssh_stdin.channel.send_ready():
                    b=f.read(ssh_stdin._bufsize)
                    if len(b)<1: break
                    ssh_stdin.write(b)
                    ssh_stdin.flush()
            ssh_stdin.flush()
            self.__waittofinsih(ssh_stdin, ssh_stdout, ssh_stderr)
            self.__client.close()
        except Exception as e:
            self.__client.close()
            raise e

    def download(self, remotefile, localfile):
        try:
            self.__client.connect(hostname=self.getConnectionDetails().getHost(), port=self.getConnectionDetails().getPort(), username=self.getConnectionDetails().getAuth()[0], password=self.getConnectionDetails().getAuth()[1], compress=True)
            ssh_stdin, ssh_stdout, ssh_stderr = self.__client.exec_command("hdfs dfs -cat "+self._formatResource("/user/"+self.getConnectionDetails().getUser()+"/"+remotefile))
            out=self.__waittofinsih(ssh_stdin, ssh_stdout, ssh_stderr, stdout_tofile=localfile)
            self.__client.close()
        except Exception as e:
            self.__client.close()
            raise e
        r={}
        for i in out.decode("utf-8").strip("\n").split("\n"):
            if len(i)>0: r.update({i:{"msg":"Detail functionality is turned off for now."}})
        return r


    def append(self, localfile, remotefile):
        try:
            self.__client.connect(hostname=self.getConnectionDetails().getHost(), port=self.getConnectionDetails().getPort(), username=self.getConnectionDetails().getAuth()[0], password=self.getConnectionDetails().getAuth()[1], compress=True)            
            ssh_stdin, ssh_stdout, ssh_stderr = self.__client.exec_command("hdfs dfs -appendToFile - "+self._formatResource("/user/"+self.getConnectionDetails().getUser()+"/"+remotefile))
            f=open(localfile,'rb')
            ssh_stdin.flush()
            while True:
                if ssh_stdin.closed:
                    raise RequestException("Input channel is closed.") 
                if ssh_stdin.channel.send_ready():
                    b=f.read(ssh_stdin._bufsize)
                    if len(b)<1: break
                    ssh_stdin.write(b)
                    ssh_stdin.flush()
            ssh_stdin.flush()
            self.__waittofinsih(ssh_stdin, ssh_stdout, ssh_stderr)
            self.__client.close()
        except Exception as e:
            self.__client.close()
            raise e

    def delete(self, path):
        try:
            self.__client.connect(hostname=self.getConnectionDetails().getHost(), port=self.getConnectionDetails().getPort(), username=self.getConnectionDetails().getAuth()[0], password=self.getConnectionDetails().getAuth()[1], compress=True)
            ssh_stdin, ssh_stdout, ssh_stderr = self.__client.exec_command("hdfs dfs -rm -f -r -skipTrash "+self._formatResource("/user/"+self.getConnectionDetails().getUser()+"/"+path))
            self.__waittofinsih(ssh_stdin, ssh_stdout, ssh_stderr)
            self.__client.close()
        except Exception as e:
            self.__client.close()
            raise e

 

