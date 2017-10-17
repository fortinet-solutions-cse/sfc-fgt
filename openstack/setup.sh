#!/bin/bash
set -x -e

. ~/nova.rc

./cleanup.sh

cat >env.sh <<EOF

source ~/nova.rc

floatIpClient="10.10.11.40"
floatIpServer="10.10.11.41"

neutron port-list >port-list

pClientMid=\$(cat port-list|grep pClientM|awk  '{print \$2}')
pClientMip=\$(cat port-list|grep pClientM|awk '{print \$11}'|cut -d "\"" -f2)

#pClientDummyMid=\$(cat port-list|grep pClientDummyM|awk  '{print \$2}')
#pClientDummyMip=\$(cat port-list|grep pClientDummyM|awk '{print \$11}'|cut -d "\"" -f2)

pServerMid=\$(cat port-list|grep pServerM|awk  '{print \$2}')
pServerMip=\$(cat port-list|grep pServerM|awk '{print \$11}'|cut -d "\"" -f2)

#pServerDummyMid=\$(cat port-list|grep pServerDummyM|awk  '{print \$2}')
#pServerDummyMip=\$(cat port-list|grep pServerDummyM|awk '{print \$11}'|cut -d "\"" -f2)

EOF


openstack network create netM --provider-network-type vxlan --disable-port-security
openstack subnet create --network netM --subnet-range 192.168.7.0/24 netM_subnet

openstack network create netServerM --provider-network-type vxlan --disable-port-security
openstack subnet create --network netServerM --subnet-range 192.168.7.0/24 netServerM_subnet

openstack image create --file fortios.qcow2 --public "FortiGate" --disk-format qcow2 --container-format bare

openstack flavor create --ram 512 --disk 8 --vcpus 1 m1.smaller
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack flavor create --ram 1024 --disk 3 --vcpus 1 --ephemeral 5 m1.fortigate


. env.sh
openstack floating ip create --floating-ip-address $floatIpClient ext_net
openstack floating ip create --floating-ip-address $floatIpServer ext_net

openstack keypair create  t1 >t1.pem
chmod 600 t1.pem

openstack port create --network netM pClientM
#openstack port create --network netM pClientDummyM
openstack port create --network netServerM pServerM
#openstack port create --network netServerM pServerDummyM
. env.sh

nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$pClientMid --key-name t1 vmClientM
nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$pServerMid --key-name t1 vmServerM

openstack server add floating ip vmClientM $floatIpClient
openstack server add floating ip vmServerM $floatIpServer

alias ssh='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

retries=40
while [ $retries -gt 0 ]
do
  ssh -i t1.pem ubuntu@$floatIpClient "ifconfig; sudo dhclient; sleep 2; ifconfig"
  result1=$?
  ssh -i t1.pem ubuntu@$floatIpServer "ifconfig; sudo dhclient; sleep 2; ifconfig"
  result2=$?
  if [ $result1 -eq 0 ] && [ $result2 -eq 0 ] ; then
     break
  elif [ $retries -eq 1 ] ; then
     echo "Servers not ready. Aborting..."
     exit -1
  fi
  sleep 1
  retries=$((retries-1))
done

ssh -i t1.pem ubuntu@$floatIpClient "sudo arp -i eth1 -s $pServerMip $(grep pServerM port-list|awk '{print $6}')"
ssh -i t1.pem ubuntu@$floatIpServer "sudo arp -i eth1 -s $pClientMip $(grep pClientM port-list|awk '{print $6}')"

ssh -i t1.pem ubuntu@$floatIpClient "sudo arp -an"
ssh -i t1.pem ubuntu@$floatIpServer "sudo arp -an"

#ssh -i t1.pem ubuntu@$floatIpClient "sudo ip route add $pServerMip/24 dev eth1 proto kernel scope link src $pClientMip"
ssh -i t1.pem ubuntu@$floatIpClient "sudo ip r"


neutron port-pair-create --ingress=${pClientMid} --egress=${pClientMid} ppClientM
neutron port-pair-create --ingress=${pServerMid} --egress=${pServerMid} ppServerM

neutron port-pair-group-create --port-pair ppClientM pgClientM
neutron port-pair-group-create --port-pair ppServerM pgServerM
