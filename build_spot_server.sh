#!/bin/bash

. ./build_config.sh

# cleanup partial instance requests later <- bug
if [ ! -e $server_sir_file ]
then
  echo "Please launch instances before building them up"
  exit 1
fi

# Load subnet and vpc id from infra file
subnet_id=$(cat $subnet_file)
security_group_id=$(cat $sg_file)

# Use the existing requests
server_spot_request_id_array=( $(cat $server_sir_file) )
Len=${#server_spot_request_id_array[@]}
for (( i=0; i<${Len}; i++ ));
do
  echo "Using ${server_spot_request_id_array[i]}"
done

# Check if any of our instances have launched, if not, launch them
request_list=${server_spot_request_id_array[*]}
request_length=${#server_spot_request_id_array[@]}
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

# Take a backup of any existing instance files
mv $server_instance_file ${server_instance_file}.bak > /dev/null 2>&1

fulfilled_array=( $(ec2-describe-spot-instance-requests -region $region $request_list | grep active | awk '{ print $8 }') )
fulfilled_size=${#fulfilled_array[@]}
for (( i=0; i<${fulfilled_size}; i++ )); do
  server_instance_id=${fulfilled_array[i]}
  echo "Created instance: $server_instance_id"

  # Wait for the node to be in 'running' state
  while ! ec2-describe-instances -region $region $server_instance_id | grep -q 'running'; do sleep 1; done

  # Retrieve IP address
  server_public_ip=$(ec2-describe-instances -region $region $server_instance_id | grep '^INSTANCE' | awk '{print $12}')
  echo "Instance started: Host address is $server_public_ip"

  echo Performing instance setup
  while ! ssh-keyscan -t ecdsa $server_public_ip 2>/dev/null | grep -q $server_public_ip; do sleep 2; done
  ssh-keyscan -t ecdsa $server_public_ip >> ~/.ssh/known_hosts 2>/dev/null
  echo "Added $server_public_ip to known hosts"

  server_private_ip=$(ec2-describe-instances -region $region $server_instance_id | grep '^INSTANCE' | awk '{print $13}')
  # Add ip address to list of servers
  all_server_ips="$server_public_ip $all_server_ips"
  all_private_ips="$server_private_ip $all_private_ips"

  # Copy over server setup script
  scp -i $EC2_KEY_LOCATION setup_server.sh $EC2_USER@$server_public_ip:/tmp
  echo $server_instance_id >> $server_instance_file
done

server_ip_array=(${all_server_ips// / })
for (( i=0; i<${fulfilled_size}; i++ )); do
  # Retrieve instance id
  server_instance_id=${fulfilled_array[i]}
  # Retrieve IP address
  #server_public_ip=$(ec2-describe-instances -region $region $server_instance_id | grep '^INSTANCE' | awk '{print $12}')
  #server_private_ip=$(ec2-describe-instances -region $region $server_instance_id | grep '^INSTANCE' | awk '{print $13}')
  # Execute server setup script with correct server ip address (1 of 4)
  echo "Running server setup script with $all_server_ips"
  ssh -i $EC2_KEY_LOCATION -t $EC2_USER@${server_ip_array[i]} "sudo bash /tmp/setup_server.sh ${server_ip_array[i]} ${server_ip_array[0]}"
done

echo $all_server_ips > $server_ip_file
echo $all_private_ips > $server_private_ip_file

