#!/bin/bash

. ./build_config.sh

# Retrieve the AMI id for Amazon Linux
ami_id=$(ec2-describe-images -o amazon --region us-west-1  -F "architecture=x86_64" -F "block-device-mapping.volume-type=gp2" -F "image-type=machine" -F "root-device-type=ebs" -F "virtualization-type=hvm" -F "name=amzn-ami-hvm-2015.03.0*" | grep "ami-" | cut -f 2)

# cleanup partial instance requests later <- bug
if [ ! -e $client_sir_file ]
then
  echo "Creating spot request for AMI: $ami_id"

  # Load subnet and vpc id from infra file
  subnet_id=$(cat $subnet_file)
  security_group_id=$(cat $sg_file)

  # Launch 4 client nodes
  client_spot_request_id_array=( $(ec2-request-spot-instances $ami_id -region $region -k $EC2_KEY_NAME -n $client_count -z $availability -t $client_instance_type -a ":0:$subnet_id:::$security_group_id" --placement-group $placement_group --associate-public-ip-address true -p $client_price | grep "sir-" | cut -f 2) )

  # get length of spot request id array
  Len=${#client_spot_request_id_array[@]}
  for (( i=0; i<${Len}; i++ ));
  do
    echo "Created ${client_spot_request_id_array[i]}"
    echo ${client_spot_request_id_array[i]} >> $client_sir_file
  done
else
  # Try to reuse the existing requests
  client_spot_request_id_array=( $(cat $client_sir_file) )
  Len=${#client_spot_request_id_array[@]}
  for (( i=0; i<${Len}; i++ ));
  do
    echo "Re-using ${client_spot_request_id_array[i]}"
  done
fi
