#!/bin/bash

# Order is important

# Delete client node(s)
./delete_client.sh

# Delete server node(s)
./delete_server.sh

# Delete infra
./delete_infra.sh

