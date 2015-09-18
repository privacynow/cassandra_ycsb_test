#!/bin/bash

# Update the server and install python (needed for aerospike)
yum -y update > /dev/null 2>&1
yum install python -y > /dev/null 2>&1

echo "[datastax]" > /etc/yum.repos.d/datastax.repo
echo "name = DataStax Repo for Apache Cassandra" >> /etc/yum.repos.d/datastax.repo
echo "baseurl = http://rpm.datastax.com/community" >> /etc/yum.repos.d/datastax.repo
echo "enabled = 1" >> /etc/yum.repos.d/datastax.repo
echo "gpgcheck = 0" >> /etc/yum.repos.d/datastax.repo

yum install dsc22 -y > /dev/null 2>&1
service cassandra stop

rm -rf /var/lib/cassandra/data/system

echo "create keyspace ycsb WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor': 1 };" > setup_ycsb.cql
echo "create table ycsb.usertable (y_id varchar primary key, field0 blob, field1 blob, field2 blob, " >> setup_ycsb.cql
echo "field3 blob, field4 blob, field5 blob, field6 blob, field7 blob, field8 blob, field9 blob) with compression = {'sstable_compression': ''};" >> setup_ycsb.cql

listen_ip=$(ifconfig eth0 | awk -F'[ :]+' '/inet addr:/{ print $4 }')
sed -i "s/listen_address:.*/listen_address: $listen_ip/" /etc/cassandra/conf/cassandra.yaml
sed -i "s/rpc_address:.*/rpc_address: $listen_ip/" /etc/cassandra/conf/cassandra.yaml
sed -i "s/seeds:.*/seeds: \"$2\"/" /etc/cassandra/conf/cassandra.yaml
sed -i "s/broadcast_address:.*/broadcast_address: $1/" /etc/cassandra/conf/cassandra.yaml
sed -i "s/# broadcast_address:.*/broadcast_address: $1/" /etc/cassandra/conf/cassandra.yaml

service cassandra start
sleep 10
server_pid=$(cat /var/run/cassandra/cassandra.pid)
taskset -p fffffffc $server_pid

# High I/O node?
if ! ethtool -i eth0 | grep -q ixgbevf ; then
  echo "Node configuration does not support high speed I/O on ethernet"
fi

# get afterburner and helper
wget https://raw.githubusercontent.com/aerospike/aerospike-server/master/tools/afterburner/afterburner.sh > /dev/null 2>&1
wget https://raw.githubusercontent.com/aerospike/aerospike-server/master/tools/afterburner/helper_afterburner.sh > /dev/null 2>&1
chmod +x afterburner.sh
chmod +x helper_afterburner.sh

echo "Optiminzing IRQs"
yes | ./afterburner.sh > /dev/null 2>&1
rm afterburner.sh
rm helper_afterburner.sh

# Get a list of IRQs for each of the ethernet interfaces
irq_script="for i in {0..3}; do grep eth\$i-TxRx /proc/interrupts | awk '{printf \"  %s\n\", \$1}' | sed -e 's/:$//'; done"
irq_array=( $(eval $irq_script) )
irq_count=${#irq_array[@]}

# Now assign SMP affinity for IRQs to first 8 cores (2 IRQs per interface, 4 interfaces)
processor=1
for (( i=0; i<$irq_count; i++ )); do
  hex_processor=$(printf "%x" $processor)
  echo "Setting processor $hex_processor affinity for handling irq ${irq_array[i]}"
  echo $hex_processor > "/proc/irq/${irq_array[i]}/smp_affinity"
  let "processor <<= 1"
done

echo "Ethernet interfaces:"
for i in {0..3}; do echo -n eth$i; ifconfig eth$i 2>&1 | grep "inet addr"; done

# Prepare cassandra for ycsb
#cqlsh $listen_ip -f setup_ycsb.cql

