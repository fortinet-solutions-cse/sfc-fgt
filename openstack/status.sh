#!/bin/bash

set -x

. env.sh

openstack network list

openstack subnet list

openstack server list

neutron flow-classifier-list

neutron port-pair-list

neutron port-pair-group-list

neutron port-chain-list

neutron port-list

openstack floating ip list

openstack flavor list

openstack image list


exit 0