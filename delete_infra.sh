#!/bin/bash

# Load configuration
. ./build_config.sh

# Load infrastructure identifiers if respective files are present
vpc_id=$(cat $vpc_file > /dev/null 2>&1)
subnet_id=$(cat $subnet_file > /dev/null 2>&1)
security_group_id=$(cat $sg_file > /dev/null 2>&1)
gw_id=$(cat $gw_file > /dev/null 2>&1)
route_table_id=$(cat $route_file> /dev/null 2>&1)

# Can't release infrastructure if server is still there
if [ -e $server_instance_file ]
then
  server_instance_id=$(cat $server_instance_file)
  echo "Unable to cleanup infra: Server $server_instance_id still running"
  exit 1
fi

# Can't release infra if there are outstanding spot instance requests
if [ -e $server_sir_file ]
then
  sir_id=$(cat $server_sir_file)
  echo "Unable to cleanup infra: Spot request $server_sir_id still outstanding"
  exit 1
fi

# This should not be needed if server has been terminated
if [ -e $eni_attachment_file ]
then
  eni_attachment_array=( $(cat $eni_attachment_file) )
  eni_size=${#eni_attachment_array[@]}

  echo "Detaching additional network interfaces ${eni_attachment_array[@]}"

  for (( i=0; i<$eni_size; i++ )) ; do
    ec2-detach-network-interface -region $region ${eni_attachment_array[i]} > /dev/null 2>&1
  done
  mv $eni_attachment_file "${eni_attachment_file}.bak"
fi

# Release extra network interfaces
if [ -e $eni_file ]
then
  eni_id_array=( $(cat $eni_file) )
  eni_size=${#eni_id_array[@]}

  echo "Deleting additional network interfaces ${eni_id_array[@]}"

  for (( i=0; i<$eni_size; i++ )) ; do
    ec2-delete-network-interface -region $region ${eni_id_array[i]}
  done
  mv $eni_file "${eni_file}.bak"
fi

# ==================== #
# Start deleting infra #
# ==================== #

if [ -e $sg_file ]
then
  echo "Deleting placement group: $placement_group"
  ec2-delete-placement-group -region $region $placement_group > /dev/null 2>&1

  security_group_id=$(cat $sg_file)
  echo "Deleting security group: $security_group_id"
  if ec2-delete-group -region $region $security_group_id 2>&1 |  grep -q 'true\|Invalid'; then
    mv $sg_file "${sg_file}.bak"
  fi
  sleep 1
fi

if [ -e $gw_file ]
then
  gw_id=$(cat $gw_file)
  echo "Deleting internet gateway $gw_id"
  sleep 1
  vpc_id=$(cat $vpc_file)
  ec2-detach-internet-gateway -region $region $gw_id -c $vpc_id > /dev/null 2>&1
  sleep 1
  if ec2-delete-internet-gateway -region $region $gw_id 2>&1 | grep -q 'true\|Invalid'; then
    mv $gw_file "${gw_file}.bak"
  fi
  sleep 1
fi

if [ -e $subnet_file ]
then
  subnet_id=$(cat $subnet_file)
  echo "Deleting subnet: $subnet_id"
  if ec2-delete-subnet -region $region $subnet_id 2>&1 |  grep -q '^SUBNET\|Invalid'; then
    mv $subnet_file "${subnet_file}.bak"
  fi
  sleep 1
fi

if [ -e $route_file ]
then
  route_table_id=$(cat $route_file)
  echo "Deleting route table $route_table_id"
  sleep 1
  if ! ec2-delete-route-table -region $region $route_table_id 2>&1 |  grep -q 'Dependency'; then
    while ! ec2-delete-route-table -region $region $route_table_id 2>&1 | grep -q 'true' ; do
      sleep 1;
      if ec2-delete-route-table -region $region $route_table_id 2>&1 |  grep -q 'Invalid\|Dependency'; then
        break
      fi
    done
  mv $route_file "${route_file}.bak"
  fi
fi

if [ -e $vpc_file ]
then
  vpc_id=$(cat $vpc_file)
  echo "Deleting vpc: $vpc_id"
  ec2-delete-vpc -region $region $vpc_id
  if ec2-delete-vpc -region $region $vpc_id  2>&1 |  grep -q '^VPN\|Invalid'; then
    mv $vpc_file "${vpc_file}.bak"
  fi
  sleep 1
fi

