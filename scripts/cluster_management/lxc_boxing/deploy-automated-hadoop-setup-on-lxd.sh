#!/bin/bash
#set -x

#########################################################################################################
#s99_runYarnJob /media/sf_D_DRIVE/credo_workspace/spark_experiment/spark-experiment-dist/target/spark-experiment-dist/spark-experiment-client-0.1.0.jar --argtoappmaster.arg1=CMDLINEAPPMASTERARG


# general settings
export FEDORA_VERSION=$(uname -r | rev | cut -d. -f2 | rev | tr -d [:alpha:])
export MASTER_NAME="master"
export EDGE_NAME="edge"
export NODE_NAMES=("node1" "node2") # space is item separator!!!
export HDFS_PATH="/home/hadoop/hdfs"
export SCRIPTGEN_DIR=/tmp/lxc_hadoop
export JAVA_PKG="java-1.8.0-openjdk"
export JAVA_HOME="/usr/lib/jvm/jre"
export JOBS_HOME="/home/hadoop/jobs"
export CPU_NUM=("4" "2" "2") # space is item separator!!!  
export MAX_MEM=("2048" "2048" "2048") # space is item separator, megabytes!!!
export EXTRA_JAVA_OPTS="-XX:ReservedCodeCacheSize=100M -XX:MaxMetaspaceSize=256m -XX:CompressedClassSpaceSize=256m"
  
#########################################################################################################

s99_loginMasterAsUserHadoop(){
  lxc-attach --elevated-privileges -n $MASTER_NAME -- su -- hadoop -c "cd $JOBS_HOME; bash"
}

#########################################################################################################

s99_startContainers(){
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    lxc-start -n $inode
  done
  lxc-ls -f
}

#########################################################################################################

s99_stopContainers(){
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    lxc-stop -n $inode
  done
  lxc-ls -f
}

#########################################################################################################

s99_emptyHDFS(){
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; hdfs dfs -rm -r -f -skipTrash /\*'" hadoop
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; hdfs dfs -expunge'" hadoop
}

#########################################################################################################

s99_startServices(){
  echo "Checking env, should see: JAVA_HOME, HADOOP_HOME, YARN_HOME, HADOOP_HDFS_HOME, ..."
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; env | grep [HYJ]A'" hadoop
  echo "Starting HDFS"
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; start-dfs.sh'" hadoop
  echo "Starting YARN"
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; start-yarn.sh'" hadoop
  sleep 2
  echo "Printing java processes on all nodes:"
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    echo "  Status on $inode"
    lxc-attach --elevated-privileges -n $inode -- ps ax -o command --cols 70 | grep java | while read line ; do
      echo "    $line..."
    done
  done
}

#########################################################################################################

s99_stopServices(){
  echo "Checking env, should see: JAVA_HOME, HADOOP_HOME, YARN_HOME, HADOOP_HDFS_HOME, ..."
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; env | grep [HYJ]A'" hadoop
  echo "Stopping HDFS"
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; stop-dfs.sh'" hadoop
  echo "Stopping YARN"
  lxc-attach --elevated-privileges -n $MASTER_NAME -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; stop-yarn.sh'" hadoop
  sleep 2
  echo "Printing java processes on all nodes:"
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    echo "  Status on $inode"
    lxc-attach --elevated-privileges -n $inode -- ps ax -o command --cols 70 | grep java | while read line ; do
      echo "    $line..."
    done
  done
}

#########################################################################################################

s99_showProcs(){
  echo "Printing java processes on all nodes:"
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    echo "  Status on $inode"
    lxc-attach --elevated-privileges -n $inode -- ps ax -o command --cols 70 | grep java | while read line ; do
      echo "    $line..."
    done
  done
}

#########################################################################################################

s99_runYarnJob(){
#  THISJOB=$(date +%Y%m%d_%Hh%Mm%Ss)
#  mkdir -p /var/lib/lxc/$MASTER_NAME/rootfs/$JOBS_HOME/$THISJOB
#  for ifile in $@; do
#    cp -vf $ifile /var/lib/lxc/$MASTER_NAME/rootfs/$JOBS_HOME/$THISJOB/
#  done
#  lxc-attach --elevated-privileges -n $MASTER_NAME -- chown -R -v hadoop:hadoop $JOBS_HOME/$THISJOB
  JARCLIENT=$1
  shift
  JARPATH=$( echo $JARCLIENT | rev | cut -d / -f 2-255 | rev )
  JARFILE=$( echo $JARCLIENT | rev | cut -d / -f 1 | rev )
  echo "JARPATH:   $JARPATH"
  echo "JARFILE:   $JARFILE"
  echo "ARGUMENTS: $@"
  cd $JARPATH && java -jar $JARFILE $@
}

#########################################################################################################

s99_installadditionaldeps(){
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    echo "INSTALLING ON $inode: $@"
    lxc-attach --elevated-privileges -n $inode -- dnf -y install $@
  done
}

#########################################################################################################

s99_cleanCluster(){
  echo "********** CLEANING HDFS ************"
  s99_emptyHDFS
  sleep 10
  echo "********** STOPPING SERVICES ************"
  s99_stopServices
  sleep 10
  echo "********** STOPPING CONTAINERS ************"
  s99_stopContainers
  sleep 10
  echo "********** STARTING CONTAINERS ************"
  s99_startContainers
  sleep 10
  echo "********** STARTING SERVICES ************"
  s99_startServices
  sleep 20
  echo "********** CLEANING HDFS ************"
  s99_emptyHDFS
}

#########################################################################################################

s01_mkdirs(){
  rm -rf $SCRIPTGEN_DIR
  for dir in scripts ssh apps conf; do 
    mkdir -p $SCRIPTGEN_DIR/$dir
  done
}

#########################################################################################################

s02_installandstartdeps(){
  #su -c "
    dnf install lxc lxc-templates lxc-extra debootstrap libvirt perl gpg openssh-server openssh-clients;
    systemctl stop libvirtd.service;
    systemctl stop lxc.service;
    systemctl stop sshd;
    systemctl start libvirtd.service;
    systemctl start lxc.service;
    systemctl start sshd;
    systemctl enable libvirtd.service;
    systemctl enable lxc.service;
    systemctl enable sshd;
  #"
}

#########################################################################################################

s03_launchContainers(){
    for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
      lxc-destroy -n $inode -f -s
    done

    #BRIDGENAME=$( virsh net-dumpxml default | grep "bridge name"  | sed -e "s/<.*bridge.*name//" | cut -d\' -f 2 )
    BRIDGENAME=$( brctl show | head -n 2 | tail -n 1 | cut -f1 )
    echo "BRIDGE NAME: $BRIDGENAME";
    cat /etc/lxc/default.conf | sed -e "s/lxc.network.link.*/lxc.network.link = $BRIDGENAME/" > $SCRIPTGEN_DIR/default.conf
    mv -v -f $SCRIPTGEN_DIR/default.conf /etc/lxc/default.conf
    brctl show
    cat /etc/lxc/default.conf
    lxc-checkconfig

    #lxc-create -t download -n CONTAINER_NAME -- -d fedora -r $FEDORA_VERSION -a amd64;
    #echo "lxc.id_map = u 0 100000 65536" >> /var/lib/lxc/CONTAINER_NAME/config
    #echo "lxc.id_map = g 0 100000 65536" >> /var/lib/lxc/CONTAINER_NAME/config
    #cat /var/lib/lxc/CONTAINER_NAME/config
    #chroot /var/lib/lxc/CONTAINER_NAME/rootfs/ passwd

    #/etc/subuid
    #/etc/subgid
    #root:1000000:65536
    #  sudo chown -R 1000000:1000000 /var/lib/lxc/ttt/rootfs
    #  sudo chmod 755 /var/lib/lxc
    #  sudo chmod 755 /var/lib/lxc/ttt
    #  sudo chmod 640 /var/lib/lxc/ttt/config
    #  sudo chmod 750 /var/lib/lxc/ttt/rootfs
    
    IPRANGE3=$(/sbin/ifconfig | grep $BRIDGENAME -A 1 | tail -n 1 | tr -d " " | tr -d inet | cut -d. -f 1-3)"."
    IPLAST=100
    ICTR=0 

    for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
      lxc-create -t download -n $inode -- -d fedora -r $FEDORA_VERSION -a amd64
      chroot /var/lib/lxc/$inode/rootfs/ passwd
      echo "IP SET TO: $IPRANGE3$IPLAST"
      echo "lxc.network.ipv4 = $IPRANGE3$((IPLAST++))" >> /var/lib/lxc/$inode/config 
      echo "" >> /var/lib/lxc/$inode/config 
      echo "# auto boot settings" >> /var/lib/lxc/$inode/config 
      echo "lxc.start.auto = 1" >> /var/lib/lxc/$inode/config
      if ("$inode" != "$MASTER_NAME"); then
      echo "lxc.start.delay = 5" >> /var/lib/lxc/$inode/config
      fi
      echo "" >> /var/lib/lxc/$inode/config 
      # THIS IS NOT WORKING! JUST LET IT GO AND ACCEPT SHARING PROCS -> TAKE INTO ACCOUNT 
      #echo "# memory and cpu limits" >> /var/lib/lxc/$inode/config 
      #inode_mem=${MAX_MEM[${ICTR}]}
      #echo "lxc.cgroup.memory.limit_in_bytes=${inode_mem}"  >> /var/lib/lxc/$inode/config
      #inode_cpu=${CPU_ORD[$((ICTR++))]}
      #echo "lxc.cgroup.cpuset.cpus=${inode_cpu}"  >> /var/lib/lxc/$inode/config
      echo "-----------------------------------------------"
      echo "CONFIG: $inode -> /var/lib/lxc/$inode/config"
      echo "-----------------------------------------------"
      cat /var/lib/lxc/$inode/config
      lxc-start -n $inode
    done

    #  su -c "
    #    systemctl status libvirtd.service | grep range;
    #    lxc-checkconfig;
    #  "
    #
    #  su -c "
    #    lxc-create -t download -n CONTAINER_NAME -- -d fedora -r $FEDORA_VERSION -a amd64;
    #    chroot /var/lib/lxc/CONTAINER_NAME/rootfs/ passwd;
    #    lxc-start -n CONTAINER_NAME;
    #  "
    ##$ lxc-console -n CONTAINER_NAME
    #
    
    systemctl status libvirtd.service | grep range
    lxc-ls -f

    virsh net-dumpxml default | sed -e "s/<name>.*default.*<\/name>/<name>hadoop_net_domain<\/name>/" | sed -e "s/<.*range.*start.*end.*>/<range start='${IPRANGE3}25' end='${IPRANGE3}75' \/>/" > $SCRIPTGEN_DIR/default.xml
    cat $SCRIPTGEN_DIR/default.xml
    virsh net-define $SCRIPTGEN_DIR/default.xml
    virsh net-start hadoop_net_domain
    virsh net-autostart hadoop_net_domain
    virsh net-list --all

    s99_startmachines
    sleep 10

}

#########################################################################################################

s04_setupSystemsInConainers(){

  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    echo "$inode"
    lxc-attach --elevated-privileges -n $inode -- systemctl stop firewalld.service
    lxc-attach --elevated-privileges -n $inode -- systemctl disable firewalld.service
    lxc-attach --elevated-privileges -n $inode -- systemctl stop iptables.service
    lxc-attach --elevated-privileges -n $inode -- systemctl disable iptables.service
    lxc-attach --elevated-privileges -n $inode -- dnf install -y tar sudo net-tools mc nedit openssh-server openssh-clients $JAVA_PKG cmake ca-certificates wget curl gcc-c++
    lxc-attach --elevated-privileges -n $inode -- systemctl start sshd.service
    lxc-attach --elevated-privileges -n $inode -- systemctl enable sshd.service
    lxc-stop -n $inode
    lxc-start -n $inode
  done
}

#########################################################################################################

#s05_getHostInfo(){
#  export HADOOP_MASTER_IP=`lxc list hadoop-master | grep RUNNING | awk '{print $6}'`
#  export HADOOP_SLAVE1_IP=`lxc list hadoop-slave-1 | grep RUNNING | awk '{print $6}'`
#  export HADOOP_SLAVE2_IP=`lxc list hadoop-slave-2 | grep RUNNING | awk '{print $6}'`
#  export N1="hadoop-master"
#  export N2="hadoop-slave-1"
#  export N3="hadoop-slave-2"
#  export HDFS_PATH="/home/hadoop/hdfs"
#}


#########################################################################################################

s06_createScripts(){

mkdir -pv /tmp/lxc_hadoop/scripts

cat > $SCRIPTGEN_DIR/scripts/setup-user.sh << EOF
export JAVA_HOME=$JAVA_HOME
export PATH="\$PATH:\$JAVA_HOME/bin"
useradd -m -s /bin/bash -G wheel hadoop
echo -e "hadoop\nhadoop" | passwd hadoop
sudo su -c "ssh-keygen -q -t rsa -f /home/hadoop/.ssh/id_rsa -N ''" hadoop
sudo su -c "cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys" hadoop
sudo su -c "mkdir -p /home/hadoop/hdfs/{namenode,datanode}" hadoop
sudo su -c "chown -R hadoop:hadoop /home/hadoop" hadoop
EOF

cat > $SCRIPTGEN_DIR/scripts/hosts << EOF
127.0.0.1 localhost
EOF
BRIDGENAME=$( brctl show | head -n 2 | tail -n 1 | cut -f1 )
IPRANGE3=$(/sbin/ifconfig | grep $BRIDGENAME -A 1 | tail -n 1 | tr -d " " | tr -d inet | cut -d. -f 1-3)"."
IPLAST=100
echo "${IPRANGE3}1 $EDGE_NAME">> $SCRIPTGEN_DIR/scripts/hosts
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
echo "$IPRANGE3$((IPLAST++)) $inode">> $SCRIPTGEN_DIR/scripts/hosts
done

cat > $SCRIPTGEN_DIR/scripts/ssh.sh<< EOF
sudo su -c "ssh -o 'StrictHostKeyChecking no' 0.0.0.0 'echo 1 > /dev/null'" hadoop
EOF
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
echo "sudo su -c \"ssh -o 'StrictHostKeyChecking no' $inode 'echo 1 > /dev/null'\" hadoop" >> $SCRIPTGEN_DIR/scripts/ssh.sh
done
#sudo su -c "ssh -o 'StrictHostKeyChecking no' hadoop-master 'echo 1 > /dev/null'" hadoop
#sudo su -c "ssh -o 'StrictHostKeyChecking no' hadoop-slave-1 'echo 1 > /dev/null'" hadoop
#sudo su -c "ssh -o 'StrictHostKeyChecking no' hadoop-slave-2 'echo 1 > /dev/null'" hadoop

cat > $SCRIPTGEN_DIR/scripts/set_env.sh << EOF
export JAVA_HOME=$JAVA_HOME
export HADOOP_HOME=/usr/local/hadoop
export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin
EOF
#bash /home/hadoop/initial_setup.sh
#EOF

cat > $SCRIPTGEN_DIR/scripts/source.sh << EOF
sudo su -c "export JAVA_HOME=$JAVA_HOME" hadoop
sudo su -c "export HADOOP_HOME=/usr/local/hadoop" hadoop
sudo su -c "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop " hadoop
sudo su -c "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_COMMON_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_HDFS_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export YARN_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" hadoop
cat /root/set_env.sh >> /home/hadoop/.bashrc 
chown -R hadoop:hadoop /home/hadoop/
sudo su -c "source /home/hadoop/.bashrc" hadoop
EOF

cat > $SCRIPTGEN_DIR/scripts/start-hadoop.sh << EOF
sudo su -c "export JAVA_HOME=$JAVA_HOME" hadoop
sudo su -c "export HADOOP_HOME=/usr/local/hadoop" hadoop
sudo su -c "export HADOOP_CONF_DIR=\$HADOOP_HOME/etc/hadoop " hadoop
sudo su -c "export HADOOP_MAPRED_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_COMMON_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export HADOOP_HDFS_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export YARN_HOME=\$HADOOP_HOME" hadoop
sudo su -c "export PATH=\$PATH:\$JAVA_HOME/bin:\$HADOOP_HOME/sbin:\$HADOOP_HOME/bin" hadoop
EOF

echo "sed -i \"s/export JAVA_HOME=\\\${JAVA_HOME}/export JAVA_HOME=${JAVA_HOME//\//\\\/}/g\" /usr/local/hadoop/etc/hadoop/hadoop-env.sh" > $SCRIPTGEN_DIR/scripts/update-java-home.sh
echo 'chown -R hadoop:hadoop /usr/local/hadoop' >> $SCRIPTGEN_DIR/scripts/update-java-home.sh

echo 'echo "Executing: hadoop namenode -format: "' > $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'echo "WHOAMI:  $(whoami)"' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'echo "JAVAS:   $(env | grep JAVA)"' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'echo "HADOOPS: $(env | grep HADOOP)"' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'echo "PATHS:   $(env | grep PATH)"' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'echo "YARNS:   $(env | grep YARN)"' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'sleep 2' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'hadoop namenode -format' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'echo "Executing: start-dfs.sh"' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'sleep 2' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'start-dfs.sh' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'echo "Executing: start-yarn.sh"' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'sleep 2' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
echo 'start-yarn.sh' >> $SCRIPTGEN_DIR/scripts/initial_setup.sh
#echo "sed -i 's/bash \/home\/hadoop\/initial_setup.sh//g' /home/hadoop/.bashrc" >> $SCRIPTGEN_DIR/scripts/initial_setup.sh

# print for check
for ifile in $(ls $SCRIPTGEN_DIR/scripts/* $SCRIPTGEN_DIR/conf/* ); do 
echo "------------------------------------"
echo $ifile
echo "------------------------------------"
cat $ifile
done

}

#########################################################################################################

s07_getHadoop(){
wget  http://archive.apache.org/dist/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz -O $SCRIPTGEN_DIR/apps/hadoop-2.7.3.tar.gz
#wget  http://apache.claz.org/hadoop/common/hadoop-2.7.3/hadoop-2.7.3.tar.gz -O $SCRIPTGEN_DIR/apps/hadoop-2.7.3.tar.gz
sleep 2
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  cp -v $SCRIPTGEN_DIR/apps/hadoop-2.7.3.tar.gz /var/lib/lxc/$inode/rootfs/usr/local/hadoop-2.7.3.tar.gz
  lxc-attach --elevated-privileges -n $inode -- tar -xf /usr/local/hadoop-2.7.3.tar.gz -C /usr/local/
  lxc-attach --elevated-privileges -n $inode -- mv /usr/local/hadoop-2.7.3 /usr/local/hadoop
done
cp -v $SCRIPTGEN_DIR/apps/hadoop-2.7.3.tar.gz /usr/local/hadoop-2.7.3.tar.gz
tar -xf /usr/local/hadoop-2.7.3.tar.gz -C /usr/local/
mv /usr/local/hadoop-2.7.3 /usr/local/hadoop
#lxc file push $SCRIPTGEN_DIR/apps/hadoop-2.7.3.tar.gz hadoop-master/usr/local/hadoop-2.7.3.tar.gz
#lxc file push $SCRIPTGEN_DIR/apps/hadoop-2.7.3.tar.gz hadoop-slave-1/usr/local/hadoop-2.7.3.tar.gz
#lxc file push $SCRIPTGEN_DIR/apps/hadoop-2.7.3.tar.gz hadoop-slave-2/usr/local/hadoop-2.7.3.tar.gz
#lxc exec hadoop-master -- tar -xf /usr/local/hadoop-2.7.3.tar.gz -C /usr/local/
#lxc exec hadoop-slave-1 -- tar -xf /usr/local/hadoop-2.7.3.tar.gz -C /usr/local/
#lxc exec hadoop-slave-2 -- tar -xf /usr/local/hadoop-2.7.3.tar.gz -C /usr/local/
#lxc exec hadoop-master -- mv /usr/local/hadoop-2.7.3 /usr/local/hadoop
#lxc exec hadoop-slave-1 -- mv /usr/local/hadoop-2.7.3 /usr/local/hadoop
#lxc exec hadoop-slave-2 -- mv /usr/local/hadoop-2.7.3 /usr/local/hadoop
}

#########################################################################################################

s08_moveScripts(){
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  cp -v $SCRIPTGEN_DIR/scripts/hosts /var/lib/lxc/$inode/rootfs/etc/hosts
  cp -v $SCRIPTGEN_DIR/scripts/setup-user.sh /var/lib/lxc/$inode/rootfs/root/setup-user.sh
  cp -v $SCRIPTGEN_DIR/scripts/set_env.sh /var/lib/lxc/$inode/rootfs/root/set_env.sh
  cp -v $SCRIPTGEN_DIR/scripts/source.sh /var/lib/lxc/$inode/rootfs/root/source.sh
  cp -v $SCRIPTGEN_DIR/scripts/ssh.sh /var/lib/lxc/$inode/rootfs/root/ssh.sh
  cp -v $SCRIPTGEN_DIR/scripts/update-java-home.sh /var/lib/lxc/$inode/rootfs/root/update-java-home.sh
done
cp -v $SCRIPTGEN_DIR/scripts/start-hadoop.sh /var/lib/lxc/$MASTER_NAME/rootfs/root/start-hadoop.sh
cp -v $SCRIPTGEN_DIR/scripts/hosts /etc/hosts

#lxc file push $SCRIPTGEN_DIR/scripts/hosts hadoop-master/etc/hosts
#lxc file push $SCRIPTGEN_DIR/scripts/hosts hadoop-slave-1/etc/hosts
#lxc file push $SCRIPTGEN_DIR/scripts/hosts hadoop-slave-2/etc/hosts

#lxc file push $SCRIPTGEN_DIR/scripts/setup-user.sh hadoop-master/root/setup-user.sh
#lxc file push $SCRIPTGEN_DIR/scripts/setup-user.sh hadoop-slave-1/root/setup-user.sh
#lxc file push $SCRIPTGEN_DIR/scripts/setup-user.sh hadoop-slave-2/root/setup-user.sh

#lxc file push $SCRIPTGEN_DIR/scripts/set_env.sh hadoop-master/root/set_env.sh
#lxc file push $SCRIPTGEN_DIR/scripts/set_env.sh hadoop-slave-1/root/set_env.sh
#lxc file push $SCRIPTGEN_DIR/scripts/set_env.sh hadoop-slave-2/root/set_env.sh

#lxc file push $SCRIPTGEN_DIR/scripts/source.sh hadoop-master/root/source.sh
#lxc file push $SCRIPTGEN_DIR/scripts/source.sh hadoop-slave-1/root/source.sh
#lxc file push $SCRIPTGEN_DIR/scripts/source.sh hadoop-slave-2/root/source.sh

#lxc file push $SCRIPTGEN_DIR/scripts/ssh.sh hadoop-master/root/ssh.sh
#lxc file push $SCRIPTGEN_DIR/scripts/ssh.sh hadoop-slave-1/root/ssh.sh
#lxc file push $SCRIPTGEN_DIR/scripts/ssh.sh hadoop-slave-2/root/ssh.sh

#lxc file push $SCRIPTGEN_DIR/scripts/start-hadoop.sh hadoop-master/root/start-hadoop.sh

#lxc file push $SCRIPTGEN_DIR/scripts/update-java-home.sh hadoop-master/root/update-java-home.sh
#lxc file push $SCRIPTGEN_DIR/scripts/update-java-home.sh hadoop-slave-1/root/update-java-home.sh
#lxc file push $SCRIPTGEN_DIR/scripts/update-java-home.sh hadoop-slave-2/root/update-java-home.sh

}

#########################################################################################################

s09_generateHadoopConfig(){
  # hadoop configuration
#echo "<configuration>\n  <property>\n    <name>fs.defaultFS</name>\n     <value>hdfs://$N1:8020/</value>\n  </property>\n</configuration>" > $SCRIPTGEN_DIR/conf/core-site.xml

mkdir -p $SCRIPTGEN_DIR/conf

echo $MASTER_NAME > $SCRIPTGEN_DIR/conf/masters

echo -n "" > $SCRIPTGEN_DIR/conf/slaves 
for inode in ${NODE_NAMES[*]}; do
echo "$inode" >> $SCRIPTGEN_DIR/conf/slaves 
done

ICTR=0
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do

mkdir -p $SCRIPTGEN_DIR/conf/$inode

cat >  $SCRIPTGEN_DIR/conf/$inode/core-site.xml << EOF
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://$MASTER_NAME:8020/</value>
  </property>
</configuration>
EOF

#echo "<configuration>\n  <property>\n    <name>dfs.namenode.name.dir</name>\n    <value>file:$HDFS_PATH/namenode</value>\n  </property>\n  <property>\n    <name>dfs.datanode.data.dir</name>\n    <value>file:$HDFS_PATH/datanode</value>\n  </property>\n  <property>\n    <name>dfs.replication</name>\n    <value>2</value>\n  </property>\n  <property>\n    <name>dfs.block.size</name>\n    <value>134217728</value>\n  </property>\n  <property>\n    <name>dfs.namenode.datanode.registration.ip-hostname-check</name>\n    <value>false</value>\n  </property>\n</configuration>" > $SCRIPTGEN_DIR/conf/hdfs-site.xml

cat > $SCRIPTGEN_DIR/conf/$inode/hdfs-site.xml << EOF
<configuration>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:$HDFS_PATH/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:$HDFS_PATH/datanode</value>
  </property>
  <property>
    <name>dfs.replication</name>
    <value>2</value>
  </property>
  <property>
    <name>dfs.blocksize</name>
    <value>16777216</value> 
<!--    <value>134217728</value> -->
  </property>
  <property>
    <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
    <value>false</value>
  </property>
  <property>
    <name>dfs.webhdfs.enabled</name>
    <value>true</value>
  </property>  
</configuration>
EOF

cat > $SCRIPTGEN_DIR/conf/$inode/mapred-site.xml << EOF
<configuration>
  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>
  <property>
    <name>mapreduce.jobhistory.address</name>
    <value>$MASTER_NAME:10020</value>
  </property>
  <property>
    <name>mapreduce.jobhistory.webapp.address</name>
    <value>$MASTER_NAME:19888</value>
  </property>
  <property>
    <name>mapred.child.java.opts</name>
    <value>-Djava.security.egd=file:/dev/../dev/urandom</value>
  </property>
  <property>
    <name>mapreduce.map.memory.mb</name>
    <value>${MAX_MEM[$ICTR]}</value>
  </property>
  <property>
    <name>mapreduce.map.cpu.vcores</name>
    <value>${CPU_NUM[$ICTR]}</value>
  </property>
  <property>
    <name>mapreduce.map.java.opts</name>
    <value>-Xmx${MAX_MEM[$ICTR]}m $EXTRA_JAVA_OPTS</value>
  </property>
  <property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>${MAX_MEM[$ICTR]}</value>
  </property>
  <property>
    <name>mapreduce.reduce.cpu.vcores</name>
    <value>${CPU_NUM[$ICTR]}</value>
  </property>
  <property>
    <name>mapreduce.reduce.java.opts</name>
    <value>-Xmx${MAX_MEM[$ICTR]}m $EXTRA_JAVA_OPTS</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>${MAX_MEM[$ICTR]}</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.cpu-vcores</name>
    <value>${CPU_NUM[$ICTR]}</value>
  </property>
  <property>
    <name>yarn.app.mapreduce.am.command-opts</name>
    <value>-Xmx${MAX_MEM[$ICTR]}m $EXTRA_JAVA_OPTS</value>
  </property>  
</configuration>
EOF

cat > $SCRIPTGEN_DIR/conf/$inode/yarn-site.xml << EOF
<configuration>
  <property>
    <name>yarn.log-aggregation-enable</name>
    <value>true</value>
  </property>
  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>$MASTER_NAME</value>
  </property>
  <property>
    <name>yarn.resourcemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>yarn.nodemanager.bind-host</name>
    <value>0.0.0.0</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>
  <property>
    <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>
  <property>
    <name>yarn.nodemanager.remote-app-log-dir</name>
    <value>hdfs://$MASTER_NAME:8020/var/log/hadoop-yarn/apps</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>${CPU_NUM[$ICTR]}</value>
  </property>
  <property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>${MAX_MEM[$ICTR]}</value>
  </property>
  <property>
    <name>yarn.scheduler.minimum-allocation-mb</name>
    <value>100</value>
  </property>
  <property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>${MAX_MEM[$ICTR]}</value>
  </property>
  <property>
    <name>yarn.nodemanager.pmem-check-enabled</name>
    <value>false</value>
  </property>
  <property>
    <name>yarn.nodemanager.vmem-check-enabled</name>
    <value>false</value>
  </property>  
  <property>
    <name>yarn.resourcemanager.am.max-attempts</name>
    <value>1</value>
  </property>    
</configuration>
EOF

_=$((ICTR++))
done

# print for check
for ifile in $(ls $SCRIPTGEN_DIR/conf/*/* ); do 
echo "------------------------------------"
echo $ifile
echo "------------------------------------"
cat $ifile
done

} 

#########################################################################################################

s10_moveHadoopConfs(){

for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  cp -v $SCRIPTGEN_DIR/conf/masters         /var/lib/lxc/$inode/rootfs/usr/local/hadoop/etc/hadoop/masters
  cp -v $SCRIPTGEN_DIR/conf/slaves          /var/lib/lxc/$inode/rootfs/usr/local/hadoop/etc/hadoop/slaves
  cp -v $SCRIPTGEN_DIR/conf/$inode/core-site.xml   /var/lib/lxc/$inode/rootfs/usr/local/hadoop/etc/hadoop/core-site.xml
  cp -v $SCRIPTGEN_DIR/conf/$inode/hdfs-site.xml   /var/lib/lxc/$inode/rootfs/usr/local/hadoop/etc/hadoop/hdfs-site.xml
  cp -v $SCRIPTGEN_DIR/conf/$inode/mapred-site.xml /var/lib/lxc/$inode/rootfs/usr/local/hadoop/etc/hadoop/mapred-site.xml
  cp -v $SCRIPTGEN_DIR/conf/$inode/yarn-site.xml   /var/lib/lxc/$inode/rootfs/usr/local/hadoop/etc/hadoop/yarn-site.xml
done
cp -v $SCRIPTGEN_DIR/conf/masters         	 /usr/local/hadoop/etc/hadoop/masters
cp -v $SCRIPTGEN_DIR/conf/slaves          	 /usr/local/hadoop/etc/hadoop/slaves
cp -v $SCRIPTGEN_DIR/conf/$inode/core-site.xml   /usr/local/hadoop/etc/hadoop/core-site.xml
cp -v $SCRIPTGEN_DIR/conf/$inode/hdfs-site.xml   /usr/local/hadoop/etc/hadoop/hdfs-site.xml
cp -v $SCRIPTGEN_DIR/conf/$inode/mapred-site.xml /usr/local/hadoop/etc/hadoop/mapred-site.xml
cp -v $SCRIPTGEN_DIR/conf/$inode/yarn-site.xml   /usr/local/hadoop/etc/hadoop/yarn-site.xml

#lxc file push $SCRIPTGEN_DIR/conf/masters hadoop-master/usr/local/hadoop/etc/hadoop/masters
#lxc file push $SCRIPTGEN_DIR/conf/masters hadoop-slave-1/usr/local/hadoop/etc/hadoop/masters
#lxc file push $SCRIPTGEN_DIR/conf/masters hadoop-slave-2/usr/local/hadoop/etc/hadoop/masters

#lxc file push $SCRIPTGEN_DIR/conf/slaves hadoop-master/usr/local/hadoop/etc/hadoop/slaves
#lxc file push $SCRIPTGEN_DIR/conf/slaves hadoop-slave-1/usr/local/hadoop/etc/hadoop/slaves
#lxc file push $SCRIPTGEN_DIR/conf/slaves hadoop-slave-2/usr/local/hadoop/etc/hadoop/slaves

#lxc file push $SCRIPTGEN_DIR/conf/core-site.xml hadoop-master/usr/local/hadoop/etc/hadoop/core-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/core-site.xml hadoop-slave-1/usr/local/hadoop/etc/hadoop/core-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/core-site.xml hadoop-slave-2/usr/local/hadoop/etc/hadoop/core-site.xml

#lxc file push $SCRIPTGEN_DIR/conf/hdfs-site.xml hadoop-master/usr/local/hadoop/etc/hadoop/hdfs-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/hdfs-site.xml hadoop-slave-1/usr/local/hadoop/etc/hadoop/hdfs-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/hdfs-site.xml hadoop-slave-2/usr/local/hadoop/etc/hadoop/hdfs-site.xml

#lxc file push $SCRIPTGEN_DIR/conf/mapred-site.xml hadoop-master/usr/local/hadoop/etc/hadoop/mapred-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/mapred-site.xml hadoop-slave-1/usr/local/hadoop/etc/hadoop/mapred-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/mapred-site.xml hadoop-slave-2/usr/local/hadoop/etc/hadoop/mapred-site.xml

#lxc file push $SCRIPTGEN_DIR/conf/yarn-site.xml hadoop-master/usr/local/hadoop/etc/hadoop/yarn-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/yarn-site.xml hadoop-slave-1/usr/local/hadoop/etc/hadoop/yarn-site.xml
#lxc file push $SCRIPTGEN_DIR/conf/yarn-site.xml hadoop-slave-2/usr/local/hadoop/etc/hadoop/yarn-site.xml
}

#########################################################################################################

s11_configureSSH(){
# THIS MATCHES THE DEFAULT YES BUT IN THE /etc/ssh/ssh_config IT IS IN A COMMENT, SO NO EFFECT BUT WORKS AS EXPECTED
# REPLACE THE SED TO STG LIKE "s/#.*PasswordAuthentication/PasswordAuthentication yes/g" TO BE TESTED
# containers
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  lxc-attach --elevated-privileges -n $inode -- sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
  lxc-attach --elevated-privileges -n $inode -- systemctl restart sshd
  sleep 1
  lxc-attach --elevated-privileges -n $inode -- systemctl status sshd
done
# host machine, which also acts like an edge node
sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config

#for ctrs in hadoop-master hadoop-slave-1 hadoop-slave-2; do
#  lxc exec $ctrs -- sed -i "s/PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
#  lxc exec $ctrs -- /etc/init.d/ssh restart ;
#done
}

#########################################################################################################

s12_setupUsers(){
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  lxc-attach --elevated-privileges -n $inode -- bash /root/setup-user.sh
done

#lxc exec hadoop-master -- bash /root/setup-user.sh
#lxc exec hadoop-slave-1 -- bash /root/setup-user.sh
#lxc exec hadoop-slave-2 -- bash /root/setup-user.sh
}

#########################################################################################################

s13_setupPasswordlessSSH(){
mkdir -p $SCRIPTGEN_DIR/ssh
PUBFILES=""
# containers - keys
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  cp -v /var/lib/lxc/$inode/rootfs/home/hadoop/.ssh/id_rsa.pub $SCRIPTGEN_DIR/ssh/id_rsa_${inode}.pub
  PUBFILES+=" $SCRIPTGEN_DIR/ssh/id_rsa_${inode}.pub"
done
# edge - keys
ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N ''
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
cp -v ~/.ssh/id_rsa.pub $SCRIPTGEN_DIR/ssh/id_rsa_${EDGE_NAME}.pub
PUBFILES+=" $SCRIPTGEN_DIR/ssh/id_rsa_${EDGE_NAME}.pub"
echo $PUBFILES
# redistribute the keys
cat $PUBFILES > $SCRIPTGEN_DIR/ssh/authorized_keys
cat $SCRIPTGEN_DIR/ssh/authorized_keys
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  cp -v $SCRIPTGEN_DIR/ssh/authorized_keys /var/lib/lxc/$inode/rootfs/home/hadoop/.ssh/authorized_keys
done
cp -v $SCRIPTGEN_DIR/ssh/authorized_keys ~/.ssh/authorized_keys
#
#lxc file pull hadoop-master/home/hadoop/.ssh/id_rsa.pub $SCRIPTGEN_DIR/ssh/id_rsa1.pub
#lxc file pull hadoop-slave-1/home/hadoop/.ssh/id_rsa.pub $SCRIPTGEN_DIR/ssh/id_rsa2.pub
#lxc file pull hadoop-slave-2/home/hadoop/.ssh/id_rsa.pub $SCRIPTGEN_DIR/ssh/id_rsa3.pub
#cat $SCRIPTGEN_DIR/ssh/id_rsa1.pub $SCRIPTGEN_DIR/ssh/id_rsa2.pub $SCRIPTGEN_DIR/ssh/id_rsa3.pub > $SCRIPTGEN_DIR/ssh/authorized_keys
#lxc file push $SCRIPTGEN_DIR/ssh/authorized_keys hadoop-master/home/hadoop/.ssh/authorized_keys
#lxc file push $SCRIPTGEN_DIR/ssh/authorized_keys hadoop-slave-1/home/hadoop/.ssh/authorized_keys
#lxc file push $SCRIPTGEN_DIR/ssh/authorized_keys hadoop-slave-2/home/hadoop/.ssh/authorized_keys
}

#########################################################################################################

s14_ensureSSH(){
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  lxc-attach --elevated-privileges -n $inode -- bash /root/ssh.sh
done
#lxc exec hadoop-master -- bash /root/ssh.sh
#lxc exec hadoop-slave-1 -- bash /root/ssh.sh
#lxc exec hadoop-slave-2 -- bash /root/ssh.sh
}

#########################################################################################################

s15_moveInitialScript(){
cp -v $SCRIPTGEN_DIR/scripts/initial_setup.sh /var/lib/lxc/$MASTER_NAME/rootfs/home/hadoop/initial_setup.sh
lxc-attach --elevated-privileges -n $MASTER_NAME -- chown hadoop:hadoop /home/hadoop/initial_setup.sh
cat $SCRIPTGEN_DIR/scripts/set_env.sh >> ~/.bashrc
}

#########################################################################################################

s16_executeScripts(){

for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  lxc-attach --elevated-privileges -n $inode -- bash /root/source.sh
  lxc-attach --elevated-privileges -n $inode -- chown -R hadoop:hadoop /usr/local/hadoop
done
lxc-attach --elevated-privileges -n master -- sudo su -c "bash -c '. /home/hadoop/.bashrc ; bash /home/hadoop/initial_setup.sh'" hadoop

#lxc exec hadoop-master -- bash /root/source.sh
#lxc exec hadoop-slave-1 -- bash /root/source.sh
#lxc exec hadoop-slave-2 -- bash /root/source.sh

#lxc exec hadoop-master -- chown -R hadoop:hadoop /usr/local/hadoop
#lxc exec hadoop-slave-1 -- chown -R hadoop:hadoop /usr/local/hadoop
#lxc exec hadoop-slave-2 -- chown -R hadoop:hadoop /usr/local/hadoop

}

#########################################################################################################

s17_updateJavaHome(){
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
  lxc-attach --elevated-privileges -n $inode -- bash /root/update-java-home.sh
done
#lxc exec hadoop-master -- bash /root/update-java-home.sh
#lxc exec hadoop-slave-1 -- bash /root/update-java-home.sh
#lxc exec hadoop-slave-2 -- bash /root/update-java-home.sh
}

#########################################################################################################

s18_startHadoop(){
lxc-attach --elevated-privileges -n $MASTER_NAME -- bash -c "export JAVA_HOME=$JAVA_HOME ; env ; bash /root/start-hadoop.sh"
}

#########################################################################################################

s19_downloadSpark(){
  mkdir -pv $SCRIPTGEN_DIR/apps
  wget http://archive.apache.org/dist/spark/spark-2.2.1/spark-2.2.1-bin-hadoop2.7.tgz -O $SCRIPTGEN_DIR/apps/spark-2.2.1-bin-hadoop2.7.tgz
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    cp -v $SCRIPTGEN_DIR/apps/spark-2.2.1-bin-hadoop2.7.tgz /var/lib/lxc/$inode/rootfs/usr/local/spark-2.2.1-bin-hadoop2.7.tgz
    lxc-attach --elevated-privileges -n $inode -- tar -xf /usr/local/spark-2.2.1-bin-hadoop2.7.tgz -C /usr/local/
    lxc-attach --elevated-privileges -n $inode -- mv /usr/local/spark-2.2.1-bin-hadoop2.7 /usr/local/spark
  done
  cp -v $SCRIPTGEN_DIR/apps/spark-2.2.1-bin-hadoop2.7.tgz /usr/local/spark-2.2.1-bin-hadoop2.7.tgz
  tar -xf /usr/local/spark-2.2.1-bin-hadoop2.7.tgz -C /usr/local/
  mv /usr/local/spark-2.2.1-bin-hadoop2.7 /usr/local/spark
}

#########################################################################################################

s20_setupSpark(){
  for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
    echo "" >> /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc
    echo "export SPARK_HOME=/usr/local/spark" >> /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc
    echo "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc
    echo "export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop"  >> /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc
    echo "export SPARK_DIST_CLASSPATH=\$SPARK_HOME/jars/*" >> /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc
    echo "FILE: /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc"
    cat /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc
  done
  echo "" >> ~/.bashrc
  echo "export SPARK_HOME=/usr/local/spark" >> ~/.bashrc
  echo "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> ~/.bashrc
  echo "export HADOOP_CONF_DIR=/usr/local/hadoop/etc/hadoop"  >> ~/.bashrc
  echo "export SPARK_DIST_CLASSPATH=\$SPARK_HOME/jars/*" >> ~/.bashrc
  echo "FILE: /var/lib/lxc/$inode/rootfs/home/hadoop/.bashrc"
  cat ~/.bashrc
#export HADOOP_CLASSPATH=${JAVA_HOME}/lib/tools.jar
}

#########################################################################################################

# print usage
echo "************************************************************"
echo "* Welcome to the HADOOP setup using lxc container on Fedora."
echo "************************************************************"
echo ""
#echo "How this works execute s**_commands as user you want to use. Order is important and sometimes you will be asked for root password."
echo "How this works execute s**_commands as root. Order is important."
for ifunc in $(declare -f | grep s[0-9][0-9]_.*() | cut -d\  -f1); do
echo "    $ifunc"
done
echo ""
echo "Input param check:"
echo "  Fedora version: " $FEDORA_VERSION
echo "  Master followed by slaves:"
for inode in $MASTER_NAME ${NODE_NAMES[*]}; do
echo "    $inode"
done
echo ""
echo "Login as root on $EDGE_NAME (host machine running the LXC containers) and use s99_* functions."
