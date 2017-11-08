#!/bin/bash
set -x

. ~/nova.rc

./cleanup.sh

cat >env.sh <<EOF

source ~/nova.rc

floatIpClient="10.10.11.40"
floatIpServer="10.10.11.41"

neutron port-list >port-list

pClientMid=\$(cat port-list|grep pClientM|awk  '{print \$2}')
pClientMip=\$(cat port-list|grep pClientM|awk '{print \$13}'|cut -d "\"" -f2)

pServerMid=\$(cat port-list|grep pServerM|awk  '{print \$2}')
pServerMip=\$(cat port-list|grep pServerM|awk '{print \$13}'|cut -d "\"" -f2)

EOF


openstack network create netM --provider-network-type vxlan --disable-port-security
openstack subnet create --network netM --subnet-range 192.168.7.0/24 netM_subnet

openstack network create netServerM --provider-network-type vxlan --disable-port-security
openstack subnet create --network netServerM --subnet-range 192.168.7.0/24 netServerM_subnet

openstack image create --file ~/cloud-images/mac-vwp-fortios.qcow2 --public "FortiGate.qcow2" --disk-format qcow2
if [ $? -ne 0 ]; then
  echo "Error uploading image"
  exit -1
fi

qemu-img convert ~/cloud-images/mac-vwp-fortios.qcow2 ~/cloud-images/mac-vwp-fortios.raw
openstack image create --file ~/cloud-images/mac-vwp-fortios.raw --public "FortiGate_vwp_mac_disable" --disk-format raw --container-format bare

openstack flavor create --ram 512 --disk 8 --vcpus 1 m1.smaller
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack flavor create --ram 1024 --disk 3 --vcpus 1 --ephemeral 5 m1.fortigate


. env.sh
openstack floating ip create --floating-ip-address $floatIpClient ext_net
openstack floating ip create --floating-ip-address $floatIpServer ext_net

openstack keypair create  t1 >t1.pem
chmod 600 t1.pem

openstack port create --network netM --fixed-ip ip-address=192.168.7.40 pClientM
openstack port create --network netServerM --fixed-ip ip-address=192.168.7.41 pServerM
. env.sh

nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$pClientMid --key-name t1 vmClientM
nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$pServerMid --key-name t1 vmServerM



retries=40
while [ $retries -gt 0 ]
do
  openstack server add floating ip vmClientM $floatIpClient && \
  openstack server add floating ip vmServerM $floatIpServer
  result=$?
  if [ $result -eq 0 ] ; then
     break
  elif [ $retries -eq 1 ] ; then
     echo "Servers not ready. Aborting..."
     exit -1
  fi
  sleep 5
  retries=$((retries-1))
done

sshopts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

retries=40
while [ $retries -gt 0 ]
do
  ssh $sshopts -i t1.pem ubuntu@$floatIpClient "ifconfig; sudo dhclient; sleep 2; ifconfig; sudo ethtool -K eth1 tx off;"
  result1=$?
  ssh $sshopts -i t1.pem ubuntu@$floatIpServer "ifconfig; sudo dhclient; sleep 2; ifconfig; sudo ethtool -K eth1 tx off;"
  result2=$?
  if [ $result1 -eq 0 ] && [ $result2 -eq 0 ] ; then
     break
  elif [ $retries -eq 1 ] ; then
     echo "Servers not ready. Aborting..."
     exit -1
  fi
  sleep 5
  retries=$((retries-1))
done

ssh $sshopts -i t1.pem ubuntu@$floatIpClient "sudo apt install -y openvswitch-switch;" \
 "sudo ovs-vsctl add-br br-sfc -- set bridge br-sfc protocols=OpenFlow10,OpenFlow12,OpenFlow13;" \
 "sudo ovs-vsctl add-port br-sfc eth1"


neutron port-pair-create --ingress=${pClientMid} --egress=${pClientMid} ppClientM
neutron port-pair-create --ingress=${pServerMid} --egress=${pServerMid} ppServerM

neutron port-pair-group-create --port-pair ppClientM pgClientM
neutron port-pair-group-create --port-pair ppServerM pgServerM
