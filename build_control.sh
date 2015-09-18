#!/bin/bash

# Is the controller node a yum based distro? 
if [ -n "$(which yum 2>/dev/null)" ]; then
  sudo yum -y update >/dev/null 2>&1
  sudo yum install -y java-1.8.0-openjdk-devel.x86_64 java-1.8.0-openjdk-javadoc.noarch > /dev/null 2>&1
fi

# Is it debian?
if [ -n "$(which apti 2>/dev/null)" ] ; then
  sudo apt-get update -y
  sudo apt-get upgrade -y
  sudo apt-get install openjdk-7-jdk -y
fi

# Do we have EC2 API tools installed?
if [ -z "$EC2_HOME" ]; then
  wget http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip
  sudo apt-get install unzip -y
  unzip -u ec2-api-tools.zip
  rm ec2-api-tools.zip
fi
