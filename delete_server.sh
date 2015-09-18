#!/bin/bash

# Load configuration
. ./build_config.sh

# If there is a server (file with server instance id present)
if [ -e $server_instance_file ]
then
  server_instance_id_array=( $(cat $server_instance_file) )
  server_array_size=${#server_instance_id_array[@]}

  # Terminate them all in one go
  echo "Deleting instances: ${server_instance_id_array[@]}"
  ec2-terminate-instances -region $region ${server_instance_id_array[@]}

  # We check them one instance at a time to ensure cleanup of partial launches
  for (( i=0; i<${server_array_size}; i++ )); do
    server_instance_id=${server_instance_id_array[i]}
    # Are there circumstances where this loop may get stuck? apparently yes.i
    # If we try to delete non existent or very old deleted instances <- bug
    while ! ec2-describe-instances -region $region $server_instance_id | grep -q 'terminated'; do
      sleep 1;
      if ec2-describe-instances -region $region $server_instance_id 2>&1 | grep -q 'Invalid'; then
        break
      fi
    done
  done

  mv $server_instance_file "${server_instance_file}.bak" > /dev/null 2>&1
  mv $server_sir_file "${server_sir_file}.bak" > /dev/null 2>&1
  sleep 1
fi

# Cleanup any outstanding spot instance requests
if [ -e $server_sir_file ]
then
  server_sir_id_array=( $(cat $server_sir_file) )

  request_list=${server_sir_id_array[*]}
  request_length=${#server_list[@]}

  echo "Deleting spot instance requests $request_list"
  ec2-cancel-spot-instance-requests -region $region $request_list
  mv $server_sir_file "${server_sir_file}.bak" > /dev/null 2>&1
  sleep 1
fi

