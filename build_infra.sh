#!/bin/bash

# Load configuration
. ./build_config.sh

# If there is no existing virtual private cloud 
if [ ! -e $vpc_file ]
then
  # Create one and save its id to a file for future reference
  vpc_id=$(ec2-create-vpc -region $region $cidr | awk '{print $2}')
  echo "Created vpc: $vpc_id"
  echo $vpc_id > $vpc_file

  # Wait till it is fully available
  while ! ec2-describe-vpcs -region $region $vpc_id | grep -q 'available'; do sleep 1; done
else
  # Reuse existing virtual private cloud
  vpc_id=$(cat $vpc_file)
  echo "Using existing vpc: $vpc_id"
fi

# We need an internet gateway in order for our VPC to be reachable from outside
if [ ! -e $gw_file ]
then
  gw_id=$(ec2-create-internet-gateway -region $region | cut -f 2)
  echo "Created internet gateway $gw_id"
  echo $gw_id > $gw_file

  ec2-attach-internet-gateway -region $region $gw_id -c $vpc_id
else
  gw_id=$(cat $gw_file)
  echo "Using existing internet gateway $gw_id"
fi

# Create a private subnet within the VPC for our use
if [ ! -e $subnet_file ]
then
  subnet_id=$(ec2-create-subnet -region $region -z $availability -c $vpc_id -i $cidr | awk '{print $2}')
  echo "Created subnet: $subnet_id"
  echo $subnet_id > $subnet_file
  while ! ec2-describe-subnets -region $region $subnet_id | grep -q 'available'; do sleep 1; done
else
  subnet_id=$(cat $subnet_file)
  echo "Using existing subnet: $subnet_id"
fi

# Create a new routing table for this vpc and associate internet routing (using internet gateway we created earlier)
if [ ! -e $route_file ]
then
  route_table_id=$(ec2-create-route-table -region $region $vpc_id | grep ROUTETABLE | cut -f 2)
  echo "Created route table $route_table_id"
  echo $route_table_id > $route_file

  ec2-associate-route-table -region $region $route_table_id -s $subnet_id
  ec2-create-route -region $region $route_table_id -r $inter_webternet -g $gw_id
else
  route_table_id=$(cat $route_file)
  echo "Using existing routing table $route_table_id"
fi

# Create firewall rules (basically poke holes that we need)
if [ ! -e $sg_file ]
then
  security_group_id=$(ec2-create-group -region $region $security_group -d bench -c $vpc_id | awk '{print $2}')
  echo "Created security group: $security_group_id"
  echo $security_group_id > $sg_file
  sleep 1

  ports_array=(${ports_to_open// / })
  ports_size=${#ports_array[@]}
  for (( i=0; i<${ports_size}; i++ )); do
    ec2-authorize -region $region $security_group_id -P TCP -p ${ports_array[i]} -s $inter_webternet
  done
  ec2-create-placement-group -region $region -s cluster $placement_group
else
  security_group_id=$(cat $sg_file)
  echo "Using existing security_group: $security_group_id"
fi

# Create three additional network interfaces so that the server can have a total of 4 attached (it comes with one)
# This allows us to distribute network traffic over multiple ethernet interfaces, each with its own IRQ and each
# IRQ mapped to a dedicated core or processor. We also create task/process affinity for database so it uses its own
# set of cpu/cores that don't overlap with I/O handling cpu/cores
if [ ! -e $eni_file ]
then
  # Create three additional network interfaces for a total of 4 on the server
  ec2-create-network-interface -region $region -g $security_group_id $subnet_id | grep "^NETWORK" | cut -f 2 >> $eni_file
  ec2-create-network-interface -region $region -g $security_group_id $subnet_id | grep "^NETWORK" | cut -f 2 >> $eni_file
  ec2-create-network-interface -region $region -g $security_group_id $subnet_id | grep "^NETWORK" | cut -f 2 >> $eni_file
else
  eni_id_array=( $(cat $eni_file) )
  echo "Using existing network interfaces ${eni_id_array[@]}"
fi

