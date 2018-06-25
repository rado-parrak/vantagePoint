from core.templates.hortonworkslocal import HortonWorksLocal
from core.templates.sshtunnelazure import TunnelSSHAzure
from time import sleep

def LivyTest(h):

    print("*** HANDLER ID ***")
    livy=h.getLivyHandler()
    print(livy.handlerId())

    print("*** LIST BATCHES ***")
    try:
        ls=livy.list()
    except Exception as e:
        print(e)
    print(ls)

    print("*** SUBMIT A JOB ***")
    try:
        job=livy.submit(file="/media/sf_D_DRIVE/credo_spark_remote_workspace/test/src/mlexperiments/99_perf_sandbox.py",
            pyPackage="/media/sf_D_DRIVE/credo_spark_remote_workspace/test/src/mlexperiments/helpers",
            name="TESTRUN")
    except Exception as e:
        print(e)
    print(job) 
     
    sleep(5)
     
    print("*** GET A LOG ***")
    try:
        log=livy.log(str(job["id"]))
    except Exception as e:
        print(e)
    print(log) 
     
    print("*** KILL A JOB ***")
    try:
        log=livy.kill(str(job["id"]))
    except Exception as e:
        print(e)
    print(log) 

    print("*** DONE ***")

def WebhdfsTest(template):

    # some test configs
    #localfile="/media/sf_D_DRIVE/putty.log"
    localfile="/media/sf_D_DRIVE/VirtualBox-5.2.8-121009-Win.exe"
    remotedir="TESTDIR"
    remotefile=remotedir+"/uploaded.file"

    print("*** HANDLER ID ***")
    hdfs=template.getWebHDFSHandler()
    print(hdfs.handlerId())
 
    print("*** LIST DIR ***")
    try:
        ls=hdfs.list("")
    except Exception as e:
        print(e)
    print("numitems: "+str(len(ls)))
    for i in ls:
        print("%-40s=%s"%(i,str(ls[i])))

    print("*** UPLOAD FILE ***")
    try:
        hdfs.upload(localfile,remotefile)
    except Exception as e:
        print(e)
    for k,v in hdfs.list(remotedir).items(): print("%-40s=%s"%(k,str(v)))

    print("*** DOWNLOAD FILE ***")
    try:
        hdfs.download(remotefile,localfile+".rtp")
    except Exception as e:
        print(e)

    print("*** APPEND THE SAME TO UPLOAD FILE ***")
    try:
        hdfs.append(localfile,remotefile)
    except Exception as e:
        print(e)
    for k,v in hdfs.list(remotedir).items(): print("%-40s=%s"%(k,str(v)))
 
    print("*** DELETE THE SAME UPLOAD FILE BY ROOTDIR ***")
    try:
        hdfs.delete(remotedir)
    except Exception as e:
        print(e)
    for k,v in hdfs.list("").items(): print("%-40s=%s"%(k,str(v)))

    print("*** DONE ***")


print("*** GET TEMPLATE ***")
a=TunnelSSHAzure(user="credossh",authtpl=("credossh","cr3d0_Letmein"))
WebhdfsTest(a)
LivyTest(a)
l=HortonWorksLocal(user="common_data")
WebhdfsTest(l)
LivyTest(l)

