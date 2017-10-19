#!/bin/bash

set -x

. env.sh

ssh-keygen -f ~/.ssh/known_hosts -R $floatIpClient
ssh-keygen -f ~/.ssh/known_hosts -R $floatIpServer

openstack server list|egrep -e '(vmClientM|vmServerM)'| awk '{print $2}'| xargs -I[] openstack server delete []

openstack port delete pServerDummyM pClientDummyM pServerM pClientM

rm t1.pem

openstack keypair delete t1

openstack floating ip delete $floatIpClient $floatIpServer

openstack flavor delete m1.smaller m1.tiny m1.fortigate

openstack image list|grep FortiGate|awk '{print $2}'|xargs -I[] openstack image delete []

openstack network delete netM netServerM

exit 0