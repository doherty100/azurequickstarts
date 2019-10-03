#!/bin/bash

# Helper script for gen-tfvarsfile.sh

./gen-tfvarsfile.sh \
  -g "rd-vdc-eastus2-dev-rg"\
  -l "eastus2"\
  -t "{ costcenter = \"10177772\", division = \"US-CS-Heathcare-COGS\", group = \"SOUTHEAST\" }"\
  -v "rd-vdc-eastus2-dev-spokewin-vnet"\
  -a "10.1.0.0/16"\
  -s "[ { name = \"default\", address_prefix = \"10.1.0.0/24\" } ]"\
  -i "/subscriptions/f6d69ee2-34d5-4ca8-a143-7a2fc1aeca55/resourceGroups/rd-vdc-eastus2-dev-rg/providers/Microsoft.Network/virtualNetworks/rd-vdc-eastus2-dev-hub-vnet"\
  -n "rd-vdc-eastus2-dev-hub-vnet"