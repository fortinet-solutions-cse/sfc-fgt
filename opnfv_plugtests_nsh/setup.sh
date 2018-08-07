#!/bin/bash

# Creates the infrastructure needed to run a client/server vms
# plus a Fortigate in between, using Service Chaining with Tacker

source openrc

# Networks
openstack network create private
openstack subnet create --subnet-range 192.168.0.0/24 --network private private_subnet

openstack network create mgmt
openstack subnet create --subnet-range 192.168.1.0/24 --network mgmt mgmt_subnet

# Security groups
openstack security group list|grep default|awk '{print $2}'|xargs -I[] openstack --insecure security group delete []
openstack security group rule create --protocol tcp --dst-port 22 default

# Images
ls sfc_nsh_fraser.qcow2 2>/dev/null || wget http://artifacts.opnfv.org/sfc/images/sfc_nsh_fraser.qcow2
openstack image create --file fgt-nsh-6.0.qcow2 --disk-format=qcow2 fgt-nsh-6.0
openstack image create --file sfc_nsh_fraser.qcow2 --disk-format=qcow2 sfc-nsh-fraser

# Flavors
openstack flavor create --ram 1024 --disk 4 --vcpus 1 fortinet_small
openstack flavor create --ram 512 --disk 1 --vcpus 1 tiny

# Client and Server VMs
# Credentials: root/opnfv
openstack server create --flavor tiny --image sfc-nsh-fraser --nic net-id=private client
openstack server create --flavor tiny --image sfc-nsh-fraser --nic net-id=private server

# Fortigate VNF
pip install python-tackerclient==0.11.0

# Tacker
tacker vim-register --description "OpenStack XCI" --config-file vim.yaml openstack-xci

tacker vnfd-create --vnfd-file fgt-vnfd.yaml fgt-vnfd
tacker vnf-create --vim-name openstack-xci --vnfd-name fgt-vnfd fgt-vnf

# Generate param file for tacker
server_ip=$(openstack server list|grep server|awk '{print $8}'|grep -o -P '[0-9\.]*')
client_ip=$(openstack server list|grep client|awk '{print $8}'|grep -o -P '[0-9\.]*')
fgt_ip=$(openstack server list|grep fgt-nsh|awk '{print $10}'|grep -o -P '[0-9\.]*')

server_port=$(openstack port list|grep $server_ip|awk '{print $2}') 
client_port=$(openstack port list|grep $client_ip|awk '{print $2}') 

cat /dev/null>param.file
echo "net_src_port_id: "${client_port}>>param.file
echo "net_dst_port_id: "${server_port}>>param.file
echo "ip_dst_prefix: 192.168.0.0/24" >> param.file

tacker vnffgd-create --vnffgd-file fgt-vnffgd.yaml fgt-vnffgd 
tacker vnffg-create --vnffgd-name fgt-vnffgd --param-file param.file --symmetrical fgt-vnffg

spi_direct=$(ssh root@192.168.122.4 "ovs-ofctl -O openflow13 dump-flows br-int| grep nsp" | grep  -P -o 'nsp=(\K[0-9]*)'|sort -h|uniq|head -n1)
spi_reverse=$(ssh root@192.168.122.4 "ovs-ofctl -O openflow13 dump-flows br-int| grep nsp" | grep  -P -o 'nsp=(\K[0-9]*)'|sort -h|uniq|tail -n1)
echo ${spi_direct}
echo ${spi_reverse}
sed -e 's/<direct_spi_id_from_odl>/'${spi_direct}'/g' fgt-config.template > fgt-config
sed -i -e 's/<reverse_spi_id_from_odl>/'${spi_reverse}'/g' fgt-config


# Set arps on client and server

mgmt_ns=$(ssh root@192.168.122.3 ip netns |head -n1)
private_ns=$(ssh root@192.168.122.3 ip netns |tail -n1)

client_mac=$(ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} ifconfig eth0  | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
server_mac=$(ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} ifconfig eth0  | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
echo ${client_mac}
echo ${server_mac}

ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} arp -s ${server_ip} ${server_mac}
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} arp -s ${client_ip} ${client_mac}

ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} arp -a
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} arp -a


# Load config in FortiGate
cat fgt-config|ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${mgmt_ns} ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@${fgt_ip}


# Access FortiGate CLI: 
# ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${mgmt_ns} ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@${fgt_ip}

# Access Client CLI:
# ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} 

# Access Server CLI:
# ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} 
