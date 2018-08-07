#!/bin/bash

set -x

tacker vnffg-delete fgt-vnffg
tacker vnffgd-delete fgt-vnffgd

tacker vnf-delete fgt-vnf
tacker vnfd-delete fgt-vnfd

# Does not work
#tacker vim-delete openstack-xci

# Not needed
openstack image delete fgt-nsh-6.0 sfc-nsh-fraser

openstack server delete client server

openstack flavor delete tiny fortinet_small

openstack subnet delete private_subnet mgmt_subnet

openstack network delete private mgmt









