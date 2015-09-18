#!/bin/bash

# Load configuration
. ./build_config.sh

# Check to see if there a client instance file on record
if [ -e $client_instance_file ]
then
  # Load all instance ids into an array
  client_instance_id_array=( $(cat $client_instance_file) )
  client_array_size=${#client_instance_id_array[@]}

  # Terminate them all in one go
  echo "Deleting instances: ${client_instance_id_array[@]}"
  ec2-terminate-instances -region $region ${client_instance_id_array[@]}

  # We check them one instance at a time to ensure cleanup of partial launches
  for (( i=0; i<${client_array_size} && i < ${client_count}; i++ )); do
    client_instance_id=${client_instance_id_array[i]}
    #echo "Deleting instance: $client_instance_id"
    #ec2-terminate-instances -region $region $client_instance_id

    # Are there circumstances where this loop may get stuck? apparently yes.i
    # If we try to delete non existent or very old deleted instances <- bug
    while ! ec2-describe-instances -region $region $client_instance_id | grep -q 'terminated'; do sleep 1; done
  done

  mv $client_instance_file "${client_instance_file}.bak" > /dev/null 2>&1
  mv $client_sir_file "${client_sir_file}.bak" > /dev/null 2>&1
  sleep 1
fi

# Release any outstanding spot instance requests
if [ -e $client_sir_file ]
then
  client_sir_id_array=( $(cat $client_sir_file) )

  request_list=${client_sir_id_array[*]}
  request_length=${#request_list[@]}

  echo "Deleting spot instance requests $request_list"
  ec2-cancel-spot-instance-requests -region $region $request_list
  mv $client_sir_file "${client_sir_file}.bak" > /dev/null 2>&1
  sleep 1
fi

