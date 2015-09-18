Cassandra YCSB Test On AWS
==========================

Cassandra YCSB testing on AWS. This package contains scripts for building the necessary high performance infrastructure, server and clients to run a YCSB test against Cassandra in AWS.

Cassandra setup and test run on 2 clients and 2 servers - 40K TPS: https://goo.gl/photos/GdH5Ytp71uHBYyAK6
Cassandra second run with double the client threads - 80K TPS: https://goo.gl/photos/jELuQWZs1uc7ntpSA

Setup
-----

* build_config.sh:    Loads configuration for use by other scripts.
* build_control.sh:   Builds up controller node, by installing java and AWS EC2 API tools
* build_infra.sh:     Builds necessary infrastructure, inlcuding vpn, subnet, firewall and routes.
* launch_server.sh:   Launches server in AWS
* build_server.sh:    Builds a high performance server using built infrastructure and deploys aerospike
* launch_client.sh:   Launches clients in AWS
* build_client.sh:    Build clients to test Cassandra and deploy Cassandra YCSB binding to each
* build_all.sh:       Builds everything

Teardown
--------

* delete_infra.sh:    Releases infrastructure, inlcuding vpn, subnet, firewall and routes.
* delete_server.sh:   Terminates server instance
* delete_client.sh:   Terminates client nodes
* delete_all.sh:      Releases all infrastructure and terminates all nodes


Other
-----

* run_client.sh:      Runs benchmark on client node (needs to run remotely)
* run_all.sh:         Loads IP addresses of client nodes and runs benchmark in parallel

Prerequisites
-------------

* AWS access key in build_config.sh
* AWS secret key in build_config.sh
* AWS private key for launching and connecting to nodes

Usage instructions
------------------

    ./build_all.sh  <- Builds everything
    ./run_all.sh    <- Runs benchmarks
    ./delete_all.sh <- Releases all resources
