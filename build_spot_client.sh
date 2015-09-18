#!/bin/bash

. ./build_config.sh

# cleanup partial instance requests later <- bug
if [ ! -e $client_sir_file ]
then
  echo "Please launch nodes before building"
  exit 1
fi

# Load subnet and vpc id from infra file
subnet_id=$(cat $subnet_file)
security_group_id=$(cat $sg_file)

# Use the existing requests
client_spot_request_id_array=( $(cat $client_sir_file) )
Len=${#client_spot_request_id_array[@]}
for (( i=0; i<${Len}; i++ ));
do
  echo "Using ${client_spot_request_id_array[i]}"
done

request_list=${client_spot_request_id_array[*]}
request_length=${#client_spot_request_id_array[@]}
echo "Checking spot requests: $request_list"
test_value="failed"

# Check for fulfillment
while true; do
  test_array=( $(ec2-describe-spot-instance-requests -region $region $request_list) )
  # Did any of the requests fail?
  if [[ " ${test_array[@]} " =~ " ${test_value} " ]]; then
    echo "Spot request failed"
    exit 1
  fi

  # Get a list of fulfilled requests
  fulfilled_array=( $(ec2-describe-spot-instance-requests -region $region $request_list | grep active | awk '{ print $8 }') )
  fulfilled_size=${#fulfilled_array[@]}
  # Break out if all requests have been fulfilled
  if [ $fulfilled_size == $request_length ]; then
    break
  fi
  echo "Waiting for fulfillment..."
  sleep 1
done

fulfilled_array=( $(ec2-describe-spot-instance-requests -region $region $request_list | grep active | awk '{ print $8 }') )

# Load server IP addresses for client node setup
all_server_ips=$(cat $server_private_ip_file)
server_ip_array=(${all_server_ips// / })

# Take a backup of any existing instance files
mv $client_instance_file ${client_instance_file}/.bak > /dev/null 2>&1

fulfilled_size=${#fulfilled_array[@]}
for (( i=0; i<${fulfilled_size}; i++ )); do
  client_instance_id=${fulfilled_array[i]}
  echo "Created instance: $client_instance_id"

  # Wait for the node to be in 'running' state
  while ! ec2-describe-instances -region $region $iclient_instance_id | grep -q 'running'; do sleep 1; done

  # Retrieve IP address
  client_instance_address=$(ec2-describe-instances -region $region $client_instance_id | grep '^INSTANCE' | awk '{print $12}')
  all_client_ips="$client_instance_address $all_client_ips"
  echo "Instance started: Host address is $client_instance_address"

  echo Performing instance setup
  while ! ssh-keyscan -t ecdsa $client_instance_address 2>/dev/null | grep -q $client_instance_address; do sleep 2; done
  ssh-keyscan -t ecdsa $client_instance_address >> ~/.ssh/known_hosts 2>/dev/null
  echo "Added $client_instance_address to known hosts"

  # Copy over client setup script
  scp -i $EC2_KEY_LOCATION setup_client.sh $EC2_USER@$client_instance_address:/tmp
  # Execute client setup script with correct server ip address (1 of 4)
  ssh -i $EC2_KEY_LOCATION -t $EC2_USER@$client_instance_address "bash /tmp/setup_client.sh ${server_ip_array[i]}"
  echo $client_instance_id >> $client_instance_file
done

echo $all_client_ips > $client_ip_file
