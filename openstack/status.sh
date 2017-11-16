#!/bin/bash

set -x

. env.sh

openstack --insecure network list

openstack --insecure subnet list

openstack --insecure server list

openstack --insecure sfc flow classifier list

openstack --insecure sfc port pair list

openstack --insecure sfc port pair group list

openstack --insecure sfc port chain list

openstack --insecure port list

openstack --insecure floating ip list

openstack --insecure flavor list

openstack --insecure image list

exit 0