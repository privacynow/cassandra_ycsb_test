#!/bin/bash

# Load configuration
. ./build_config.sh

# Load instance ids for all clients (to get their IP addresses)
client_instance_array=( $(cat $client_instance_file) )
client_instance_count=${#client_instance_array[@]}

echo "Restarting $client_instance_count nodes (${client_instance_array[@]})"

for (( i=0; i<${client_instance_count}; i++ )); do
  client_instance_id=${client_instance_array[i]}
  client_instance_address=$(ec2-describe-instances -region $region $client_instance_id | grep '^INSTANCE' | awk '{print $12}')
  ssh -i $EC2_KEY_LOCATION -t $EC2_USER@$client_instance_address 'sudo reboot'
done

