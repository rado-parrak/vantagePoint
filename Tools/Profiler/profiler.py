import matplotlib.pyplot as plt
import csv
from influxdb.client import InfluxDBClient
from string import split
from dateutil import parser as timeparser
import argparse

# parse arguments
parser = argparse.ArgumentParser()
parser.add_argument("--heartbeatfile", default="joblog.csv", help="File of the heartbeat exports from log.")
parser.add_argument("--outdir",        default=".",          help="Directory where to render the images.")
parser.add_argument("--host",          default="localhost",  help="InfluxDB host.")
parser.add_argument("--port",          default="8085",       help="InfluxDB port.")
parser.add_argument("--database",      default="profiler",   help="InfluxDB database name.")
args=parser.parse_args()
print args

# set arguments
heartbeatfilename=args.heartbeatfile
outputdir=args.outdir
influxhost=args.host
influxport=int(args.port)
influxdb=args.database


# plotter function
def plotGraph(title, heartbeat, figs):
    hbplot=plt.subplot(2,2,3)
    plt.plot(heartbeat.x, heartbeat.y, '-')
    plt.xlabel('time')
    plt.ylabel('heartbeats')
    mainplot=plt.subplot(2, 2, 1, sharex=hbplot)
    plt.title(title)
    plt.setp(mainplot.get_xticklabels(), visible=False)
    plt.ylabel("values")
    legendplot = plt.subplot(2,2,2)
    legendplot.set_axis_off()
    legend=[]
    for i in figs:
        mainplot.plot(i.x, i.y, '-')
        legendplot.plot([0], [0], '-')
        legend.append(i.name)
    plt.legend(legend, loc='upper left', prop={"size":"small"})
    plt.savefig(outputdir+"/profile_"+title+".png", dpi=200)
    #plt.show()     
    plt.clf()
    plt.cla()
    plt.close()

# plot builder class for matplotlib and the master 
class SingleFigure:
    x=None
    y=None
    name=None
    def __init__(self, name):
        self.name=name
        self.x=[]
        self.y=[]
    def add(self,x,y):
        self.x.append(x)
        self.y.append(y)

# read the heartbeats
hbfile=csv.reader(open(heartbeatfilename, "rb"))
hbdata=SingleFigure("heartbeats")
hbshift=None
for row in hbfile:
    if (row[0]!="time"):
        if (hbshift==None):
            hbshift=long(row[0][:-6])
        if (len(hbdata.x)>0):
            hbdata.add(float(long(row[0][:-6])-hbshift)/1000.,hbdata.y[len(hbdata.y)-1])
        hbdata.add(float(long(row[0][:-6])-hbshift)/1000.,int(0))
        hbdata.add(float(long(row[0][:-6])-hbshift)/1000.,int(row[1]))

# grab the data from influxdb
influxclient = InfluxDBClient(host=influxhost,port=influxport,database=influxdb)
groupings={"other.other":[]}            
for iserie in influxclient.get_list_series(influxdb):
    for ilist in iserie["tags"]:
        if (not ilist["key"].startswith("cpu.trace")):
            tags=split(split(ilist["key"],sep=",")[0],sep=".")
            if (len(tags)>=2):
                if (tags[0]+"."+tags[1]) in groupings:
                    groupings[tags[0]+"."+tags[1]].append(ilist["key"])
                else:
                    groupings[tags[0]+"."+tags[1]]=[ilist["key"]]
            else:
                groupings["other.other"].append(ilist["key"])
for igroupname in groupings:
    figs=[]
    for iserie in groupings[igroupname]:     
        currname=split(iserie,sep=',')[0]
        currpid=split(split(iserie,sep="pid=")[1],sep=",")[0]
        icurve=SingleFigure(currname+"."+currpid)          
        iset=influxclient.query("SELECT * FROM \"" + currname + "\" ORDER BY time")
        for i in iset.get_points():
            if (i["pid"]==currpid):
                icurve.add(float(long(timeparser.parse(i["time"]).strftime("%s%f")[:-3])-hbshift)/1000., i["value"])
        figs.append(icurve)
    plotGraph(igroupname, hbdata, figs)


    
    
