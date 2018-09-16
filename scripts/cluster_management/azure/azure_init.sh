#RUN THIS AS THE SSH ADMIN
echo "Enable webhdfs through ambari after this script is finished!"

echo "RUNNING BASICS AND ADDING LINUX USERS (y/n)?"
if [ "$(read ANSWER; echo $ANSWER)" == "y" ]; then
  sudo apt -y install mc dos2unix autossh
  sudo  adduser rado
  sudo  adduser herman
  sudo  adduser tamas
  sudo  adduser common_data
fi
echo "SETTING USERS IN HDFS (y/n)?"
if [ "$(read ANSWER; echo $ANSWER)" == "y" ]; then
  sudo -u hdfs hadoop fs -mkdir /user/rado
  sudo -u hdfs hadoop fs -mkdir /user/herman
  sudo -u hdfs hadoop fs -mkdir /user/tamas
  sudo -u hdfs hadoop fs -mkdir /user/common_data
  sudo -u hdfs hadoop fs -chown -R rado:supergroup /user/rado
  sudo -u hdfs hadoop fs -chown -R herman:supergroup /user/herman
  sudo -u hdfs hadoop fs -chown -R tamas:supergroup /user/tamas
  sudo -u hdfs hadoop fs -chown -R common_data:supergroup /user/common_data
fi
echo "ADDING SUPERUSER TO HDFS (y/n)?"
if [ "$(read ANSWER; echo $ANSWER)" == "y" ]; then
  sudo -u hdfs hadoop fs -mkdir /user/${USER}
  sudo -u hdfs hadoop fs -chown -R ${USER}:supergroup /user/${USER}
fi
echo "START AUTOSSH TO BRIDGE PORT 30070 (y/n)?"
if [ "$(read ANSWER; echo $ANSWER)" == "y" ]; then
  echo "After password, press ctrl-z:"
  autossh -M 0 -q -N -o "ServerAliveInterval 60" -o "ServerAliveCountMax 3" -L 30070:hn1-credo:30070 hn0-credo
  bg
  disown
fi
