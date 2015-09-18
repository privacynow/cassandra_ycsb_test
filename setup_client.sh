#!/bin/bash

# Update the client and install java
echo "Installing java..."
sudo yum -y update > /dev/null 2>&1
sudo yum -y install java-1.8.0-openjdk-devel.x86_64 java-1.8.0-openjdk-javadoc.noarch > /dev/null 2>&1
sudo yum -y install git

# High I/O node?
if ! ethtool -i eth0 | grep -q ixgbevf ; then
  echo "Node configuration does not support high speed I/O on ethernet"
fi

# Installing maven on Amzon AMI is yucky

echo "wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo" > /tmp/install_maven.sh
echo "sed -i \"s/\\\$releasever/6/g\" /etc/yum.repos.d/epel-apache-maven.repo" >> /tmp/install_maven.sh
echo "yum -y install apache-maven > /dev/null 2>&1" >> /tmp/install_maven.sh

sudo bash /tmp/install_maven.sh

export JAVA_HOME=$(readlink -f `which javac` | sed "s:bin/javac::")

# Install python
sudo um install python -y > /dev/null 2>&1

# Checkout latest version of YCSB
git clone https://github.com/brianfrankcooper/YCSB.git

# Set cassandra driver version
sed -i "s/\(    <cassandra.version>\)\([0-9].*\)\(<\/cassandra.version.*\)/\12.2.1\3/" YCSB/pom.xml
sed -i "s/\(    <cassandra.cql.version>\)\([0-9].*\)\(<\/cassandra.cql.version.*\)/\12.0.1\3/" YCSB/pom.xml

# Edit java code to replace cluster.shutdown() from prior version of cassandra cql driver with cluster.close()
sed -i "s/cluster.shutdown.*/cluster.close();/" YCSB/cassandra/src/main/java/com/yahoo/ycsb/db/CassandraCQLClient.java

# Build YCSB
cd YCSB 
mvn package
cd ..
tar xvfz YCSB/distribution/target/ycsb*gz

sed -i "s/1000$/1000000/" ycsb-*/workloads/workloada
echo "insertstart=$2" >> ycsb-*/workloads/workloada

echo $1 > server_ip.txt
echo $3 > client_ip.txt
