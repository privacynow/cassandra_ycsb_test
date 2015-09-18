#!/bin/bash

. ./build_config.sh

# Retrieve the AMI id for Amazon Linux
ami_id=$(ec2-describe-images -o amazon --region us-west-1  -F "architecture=x86_64" -F "block-device-mapping.volume-type=gp2" -F "image-type=machine" -F "root-device-type=ebs" -F "virtualization-type=hvm" -F "name=amzn-ami-hvm-2015.03.0*" | grep "ami-" | cut -f 2)

# cleanup partial instance requests later <- bug
if [ ! -e $server_sir_file ]
then
  echo "Creating spot request for AMI: $ami_id"

  # Load subnet and vpc id from infra file
  subnet_id=$(cat $subnet_file)
  security_group_id=$(cat $sg_file)

  # Launch server nodes
  server_spot_request_id_array=( $(ec2-request-spot-instances $ami_id -region $region -k $EC2_KEY_NAME -n $server_count -z $availability -t $server_instance_type -a ":0:$subnet_id:::$security_group_id" --placement-group $placement_group --associate-public-ip-address true -p $server_price | grep "sir-" | cut -f 2) )

  # get length of spot request id array
  Len=${#server_spot_request_id_array[@]}
  for (( i=0; i<${Len}; i++ ));
  do
    echo "Created ${server_spot_request_id_array[i]}"
    echo ${server_spot_request_id_array[i]} >> $server_sir_file
  done
else
  # Try to reuse the existing requests
  server_spot_request_id_array=( $(cat $server_sir_file) )
  Len=${#server_spot_request_id_array[@]}
  for (( i=0; i<${Len}; i++ ));
  do
    echo "Re-using ${server_spot_request_id_array[i]}"
  done
fi

