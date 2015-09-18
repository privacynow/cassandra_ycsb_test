#!/bin/bash

JAVA_HOME=$(readlink -f `which javac` | sed "s:bin/javac::")
server_ip=$(cat server_ip.txt)
client_ip=$(cat client_ip.txt)

echo "Starting benchmark on: $server_ip"
cd ycsb*
./bin/ycsb load cassandra-cql -P workloads/workloada -p host=$server_ip -p port=9042 -threads 20 -s > "/tmp/results_load_$client_ip.txt"
./bin/ycsb run cassandra-cql -P workloads/workloada -p host=$server_ip -p port=9042 -threads 20 -s > "/tmp/results_run_$client_ip.txt"
