#!/bin/bash

EC2_KEY_NAME="aerospike-benchmark-key"
EC2_KEY_LOCATION=`ls *.pem`
EC2_USER=ec2-user
export AWS_ACCESS_KEY=<YOUR IAM ACCESS KEY HERE>
export AWS_SECRET_KEY=<YOUR IAM SECRET KEY HERE>

JAVA_HOME=$(readlink -f `which javac` | sed "s:bin/javac::")

api_tools=`ls -d ec2-api-tools* 2>/dev/null`
if [ -n "$api_tools" ]
then
  EC2_HOME=`pwd`/ec2-api-tools*
fi

server_instance_type="r3.8xlarge"
server_price=2
server_count=2
server_launch_group="sg_launch"
client_instance_type="r3.8xlarge"
client_price=2
client_count=2
client_launch_group="cg_launch"
region="us-west-1"
availability="us-west-1c"
placement_group="pg1"
security_group="sg1"
cidr="10.2.0.0/16"
inter_webternet="0.0.0.0/0"
ports_to_open="9042 9160 7000 7199 22"
sg_file="sg_id.txt"
vpc_file="vpc_id.txt"
subnet_file="subnet_id.txt"
gw_file="gw_id.txt"
route_file="route_table_id.txt"
eni_file="network_interface_id.txt"
eni_attachment_file="network_attachment_id.txt"

server_instance_file="server_instance_id.txt"
client_instance_file="client_instance_id.txt"
server_sir_file="server_sir_id.txt"
client_sir_file="client_sir_id.txt"
server_ip_file="server_ip.txt"
server_private_ip_file="server_private_ip.txt"
client_ip_file="client_ip.txt"

record_count=1000000
