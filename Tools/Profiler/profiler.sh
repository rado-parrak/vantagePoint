#!/bin/bash 
# -eux
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Michael Spector <spektom@gmail.com>
PYTHONCMD=python2 # python2.7
SPARKSUBMITCMD=spark2-submit


trap 'kill $(jobs -p) 2>/dev/null' EXIT

function find_unused_port() {
  for port in $(seq $1 65000); do
    if [ "$(uname)" == "Darwin" ]; then
      nc -nz 127.0.0.1 $port >/dev/null 2>&1;
    else
      echo -ne "\035" | telnet 127.0.0.1 $port >/dev/null 2>&1;
    fi
    if [ $? -eq 1 ]; then
      echo $port
      exit
    fi
  done
  echo "ERROR: Can't find unused port in range $1-65000"
  exit 1
}

function install_deps() {
  for cmd in $PYTHONCMD perl pip; do
    if ! which $cmd >/dev/null 2>&1; then
      echo "ERROR: $cmd is not installed!"
      exit 1
    fi
  done

  echo -e "[$(date +%FT%T)] Installing dependencies"
  [ ! -d $install_dir ] && mkdir $install_dir
  pushd $install_dir >/dev/null
  pip -q install --user python-dateutil==2.6.1 influxdb==2.12.0 blist pytz statsd # latest dependencies that worjs with python 2.6
  # only newer plotly are supporting offline plotly==1.6.7 -> falling back to matplotlib

  wget -qc https://github.com/etsy/statsd-jvm-profiler/releases/download/2.1.0/statsd-jvm-profiler-2.1.0-jar-with-dependencies.jar
  ln -sf statsd-jvm-profiler-2.1.0-jar-with-dependencies.jar statsd-jvm-profiler.jar

  wget -qc https://raw.githubusercontent.com/aviemzur/statsd-jvm-profiler/master/visualization/influxdb_dump.py
  wget -qc https://raw.githubusercontent.com/brendangregg/FlameGraph/master/flamegraph.pl

  if [ "$(uname)" == "Darwin" ]; then
    brew list influxdb &> /dev/null || brew install influxdb
  else
    wget -qc https://dl.influxdata.com/influxdb/releases/influxdb-1.2.4_linux_amd64.tar.gz
    tar -xzf influxdb-1.2.4_linux_amd64.tar.gz
    rm -f influxdb
    ln -s influxdb-1.2.4-1 influxdb
  fi

  popd >/dev/null
}

function run_influxdb() {
  echo -e "[$(date +%FT%T)] Starting InfluxDB"
  cat << EOF >influxdb.conf
reporting-disabled = true
hostname = "${local_ip}"
bind-address = ":${influx_meta_port}"
[meta]
  dir = "$(pwd)/influxdb/meta"
[data]
  dir = "$(pwd)/influxdb/data"
  wal-dir = "$(pwd)/influxdb/wal"
[admin]
  enabled = false
[http]
  bind-address = ":${influx_http_port}"
EOF
  rm -rf influxdb
  echo "INFLUXDSRV: $(which influxd)"
  echo "INFLLUXCLI: $(which influx)"
  influxd -config influxdb.conf >influxdb.log 2>&1 &
  influx_pid=$!

  wait_secs=5
  while [ $wait_secs -gt 0 ]; do
    if curl -sS -i $influx_uri/ping 2>/dev/null | grep X-Influxdb-Version >/dev/null; then
      break
    fi
    sleep 1
    wait_secs=$(($wait_secs-1))
  done

  if [ $wait_secs -eq 0 ]; then
    echo "ERROR: Couldn't start InfluxDB!"
    exit 1
  fi

  curl -sS -X POST $influx_uri/query --data-urlencode "q=CREATE DATABASE profiler" >/dev/null
  curl -sS -X POST $influx_uri/query --data-urlencode "q=CREATE USER profiler WITH PASSWORD 'profiler' WITH ALL PRIVILEGES" >/dev/null
}

function run_spark_submit() {
  spark_args=()

  jars=$install_dir/statsd-jvm-profiler.jar

  executor_java_opts="-javaagent:statsd-jvm-profiler.jar=server=${local_ip},\
port=${influx_http_port},reporter=InfluxDBReporter,database=profiler,\
username=profiler,password=profiler,prefix=sparkapp,tagMapping=spark"

  driver_java_opts="-javaagent:${install_dir}/statsd-jvm-profiler.jar=server=${local_ip},\
port=${influx_http_port},reporter=InfluxDBReporter,database=profiler,username=profiler,\
password=profiler,prefix=sparkapp,tagMapping=spark"

  while [[ $# > 0 ]]; do
    case "$1" in
      --jars)
        jars="$jars,$2"
        shift
        ;;
      spark.executor.extraJavaOptions=*)
        spark_args+=("$1 ${executor_java_opts}")
        executor_java_opts_patched=true
        ;;
      spark.driver.extraJavaOptions=*)
        spark_args+=("$1 ${driver_java_opts}")
        driver_java_opts_patched=true
        ;;
      *)
        spark_args+=("$1")
        [[ "$1" == *.jar ]] && flamegraph_title="$1"
        ;;
    esac
    shift
  done

  spark_cmd=("${spark_cmd}")
  spark_cmd+=(--jars)
  spark_cmd+=("${jars}")

  if [ -z ${executor_java_opts_patched+x} ]; then
    spark_cmd+=(--conf)
    spark_cmd+=("spark.executor.extraJavaOptions=-javaagent:statsd-jvm-profiler.jar\
=server=${local_ip},port=${influx_http_port},reporter=InfluxDBReporter,database=profiler,\
username=profiler,password=profiler,prefix=sparkapp,tagMapping=spark")
  fi

  if [ -z ${driver_java_opts_patched+x} ]; then
    spark_cmd+=(--conf)
    spark_cmd+=("spark.driver.extraJavaOptions=-javaagent:${install_dir}/statsd-jvm-profiler.jar\
=server=${local_ip},port=${influx_http_port},reporter=InfluxDBReporter,database=profiler,\
username=profiler,password=profiler,prefix=sparkapp,tagMapping=spark")
  fi

  if [ "${#spark_args[@]}" -gt 0 ]; then
    spark_cmd+=("${spark_args[@]}")
  fi

  echo -e "[$(date +%FT%T)] Executing: ${spark_cmd[@]}"
  "${spark_cmd[@]}" && :
  spark_exit_code=$?
  if [ $spark_exit_code -ne 0 ]; then
    echo -e "[$(date +%FT%T)] Spark has exited with bad exit code ($spark_exit_code)"
  fi
}

function generate_flamegraph() {
  rm -rf stack_traces
  echo -e "[$(date +%FT%T)] Collecting metrics"

  $PYTHONCMD $install_dir/influxdb_dump.py \
    -o $local_ip -r $influx_http_port -u profiler \
    -p profiler -d profiler -t spark -e sparkapp -x stack_traces && : #>/dev/null 2>&1 && :

  if [ $? -ne 0 ]; then
    echo -e "[$(date +%FT%T)] No metrics were recorded!"
    return 0
  fi

  perl $install_dir/flamegraph.pl \
    --title "$flamegraph_title" \
    stack_traces/all_*.txt > flamegraph.svg

  rm -rf stack_traces
  echo -e "[$(date +%FT%T)] Created flamegraph: $(pwd)/flamegraph.svg"
}

function generate_nontrace_properties(){
  echo "time,heartbeat" > joblog.csv
  cat job.log | grep "___HEARTBEAT___:" | cut -d: -f2 >> joblog.csv
  $PYTHONCMD ${0/.sh/.py} --heartbeatfile joblog.csv --host ${local_ip} --port ${influx_http_port} 
  rm joblog.csv
}

function cleanup(){
  kill -9 $influx_pid
  sleep 1
  rm -rf influxdb
  rm -rf results
  mkdir results
  mv ./profile_*.png results/
  mv flamegraph.svg results/profile_flamegraph.svg
  mv job.log results/
  mv influxdb.conf results/
  mv influxdb.log results/
}

if [ "$(uname)" == "Darwin" ]; then
  local_ip=$(ifconfig | awk '/inet / && $2 != "127.0.0.1"{print $2; exit}')
else
  local_ip=$(ip route get 8.8.8.8 | awk '{print $NF; exit}')
fi
install_dir=$HOME/.spark-flamegraph
influx_meta_port=$(find_unused_port 48080)
influx_http_port=$(find_unused_port $(($influx_meta_port+1)))
influx_uri=http://${local_ip}:${influx_http_port}
flamegraph_title="Spark Application"
spark_cmd=${SPARK_CMD:-"$SPARKSUBMITCMD"}
influx_pid=""
export PATH=$install_dir/influxdb/usr/bin:$PATH

install_deps
run_influxdb
run_spark_submit "$@"  | tee job.log
generate_flamegraph
generate_nontrace_properties
cleanup

echo "Finished."

#echo "$(ps aux | grep influx)"
#echo "INFLUXDSRV: $(which influxd)"
#echo "INFLLUXCLI: $(which influx)"
#echo "INFLUXURI:  $influx_uri"

#influx -host ${local_ip} -port ${influx_http_port} -database profiler -format csv

#rm -rf samples
#mkdir samples
#for i in $(influx -host ${local_ip} -port ${influx_http_port} -database profiler -format csv -execute "SHOW MEASUREMENTS" | grep -v "cpu.trace" | grep -v "name,name" ); do
#  #echo ${i:0:100}
#  varname=$(echo $i | cut -d, -f 2-255)
#  echo $varname
#  varlog=$(influx -host ${local_ip} -port ${influx_http_port} -database profiler -format csv -execute "SELECT * FROM \"$varname\" ORDER BY time" | tail -n +2 | cut -d, -f2,5,7)
#  #echo "$varlog"
#  for j in $varlog; do
#    echo $(cut -d, -f1,3 <<< $j ) >> samples/$varname.$(cut -d, -f2 <<< $j)
#  done 
#  for j in $(ls -1 samples/$varname.*); do
#    echo "time,$(cut -d/ -f2 <<< $j)" >> samples/${varname}.csv
#    cat $j >> samples/${varname}.csv
#  done
#done

exit $spark_exit_code
