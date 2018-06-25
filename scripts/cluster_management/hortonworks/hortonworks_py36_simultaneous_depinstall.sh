echo "Usage: run this script with a single argument how you would give a dependency to pip"
echo "Run it as root from sandbox-host."

echo "----- On host: ---"
. /opt/rh/rh-python36/enable
yolk -V $1
echo "----- On docker: ---"
docker exec -i sandbox-hdp /bin/bash -c ". /opt/rh/rh-python36/enable ; yolk -V $1"
echo "Choose version by typing the version:"
read version

pip3 install ${1}==${version}
docker exec -i sandbox-hdp /bin/bash -c ". /opt/rh/rh-python36/enable ; pip3 install ${1}==${version}"
