#!/bin/bash

set -x

. env.sh

ssh-keygen -f ~/.ssh/known_hosts -R $floatIpClient
ssh-keygen -f ~/.ssh/known_hosts -R $floatIpServer

openstack --insecure server list|egrep -e '(vmClientM|vmServerM)'| awk '{print $2}'| xargs -I[] openstack server delete []


openstack --insecure sfc port pair group delete pgClientM

openstack --insecure sfc port pair group delete pgServerM

openstack --insecure sfc port pair delete ppClientM

openstack --insecure sfc port pair delete ppServerM

openstack --insecure port delete pServerM

openstack --insecure port delete pClientM

rm t1.pem

openstack --insecure keypair delete t1

openstack --insecure floating ip delete $floatIpClient

openstack --insecure floating ip delete $floatIpServer

openstack --insecure flavor delete m1.smaller m1.tiny m1.fortigate

openstack --insecure image list|grep FortiGate|awk '{print $2}'|xargs -I[] openstack image delete []

openstack --insecure network delete netM netServerM

exit 0