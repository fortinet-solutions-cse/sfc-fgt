#!/usr/bin/bash

if [ -z "$1" ]; then
  echo "Need name of the VM to SCALE"
  exit -1
fi

VM_NAME="PEPE"

cat >env_${VM_NAME}.sh <<EOF

source ~/nova.rc

floatIp_${VM_NAME}_proxy="10.10.11.42"
floatIp_${VM_NAME}_fgt="10.10.11.43"

neutron port-list >port-list

p_${VM_NAME}_id_proxy=\$(cat port-list|grep pServerM|awk  '{print \$2}')
p_${VM_NAME}_ip_proxy=\$(cat port-list|grep pServerM|awk '{print \$11}'|cut -d "\"" -f2)

EOF

#Create networks to communicate proxy with FGT
openstack network create net_${VM_NAME}_1 --provider-network-type vxlan --disable-port-security
openstack subnet create --network net_${VM_NAME}_1 --subnet-range 10.1.1.0/24 net_${VM_NAME}_1_subnet
openstack network create net_${VM_NAME}_2 --provider-network-type vxlan --disable-port-security
openstack subnet create --network net_${VM_NAME}_2 --subnet-range 10.1.1.0/24 net_${VM_NAME}_2_subnet

#Create ports of the proxy that will be part of the chain
openstack port create --network netM p_A_proxy_$VM_NAME
openstack port create --network netServerM p_B_proxy_$VM_NAME
. env.sh


#Create floating ips for management of proxy and FGT
floating_ip_proxy=floatIp_${VM_NAME}_proxy
floating_ip_fgt=floatIp_${VM_NAME}_fgt
openstack floating ip create --floating-ip-address ${!floating_ip_proxy} ext_net
openstack floating ip create --floating-ip-address ${!floating_ip_fgt} ext_net


#Boot Proxy and FGT VMs
nova boot --flavor m1.smaller --image "Trusty x86_64"  --nic net-name=mgmt --nic port-id=$p2Mid --nic port-id=$p3Mid --key-name t1 vm2M
nova boot --flavor m1.fortigate --image "FortiGate" --nic net-name=mgmt --nic port-id=$p2Mid --nic port-id=$p3Mid --config-drive true --user-data myConfig1.txt --ephemeral size=5 vm2M

openstack server add floating ip vm1M $floatIp1
openstack server add floating ip vm2M $floatIp2
