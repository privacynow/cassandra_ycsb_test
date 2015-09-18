#!/bin/bash

# Setup this node to run ec2 api tools
./build_control.sh

# Build vpc, subnet and firewall infrastructure
./build_infra.sh

# Launch server nodes
./launch_server.sh

# Launch client nodes
./launch_client.sh

# Build server nodes
./build_server.sh

# Build client nodes
./build_client.sh

