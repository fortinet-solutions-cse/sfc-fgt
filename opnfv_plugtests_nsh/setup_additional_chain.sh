#!/bin/bash

# Creates the infrastructure needed to add a secondary server to show
# multiple chains going through FortiGate

# Always run after setup.sh

if [ ! -f openrc ]; then
    echo "openrc file not found!"
    exit -1
fi

set -x

source openrc

# Server VM
# Credentials: root/opnfv
openstack server create --flavor tiny --image sfc-nsh-fraser --nic net-id=private client2
openstack server create --flavor tiny --image sfc-nsh-fraser --nic net-id=private server2

sleep 5

# Generate param file for tacker
client_ip=$(openstack server list|grep client2|awk '{print $8}'|grep -o -P '[0-9\.]*')
server_ip=$(openstack server list|grep server2|awk '{print $8}'|grep -o -P '[0-9\.]*')

server_port=$(openstack port list|grep $server_ip|awk '{print $2}') 
client_port=$(openstack port list|grep $client_ip|awk '{print $2}') 

cat /dev/null>param2.file
echo "net_src_port2_id: "${client_port}>>param2.file
echo "net_dst_port2_id: "${server_port}>>param2.file
echo "ip_dst_prefix: 192.168.0.0/24" >> param2.file

# Tacker Create VNFFGD/VNFFG
tacker vnffgd-create --vnffgd-file fgt-vnffgd_2_chains.yaml fgt-vnffgd2 
tacker vnffg-create --vnffgd-name fgt-vnffgd2 --param-file param2.file --symmetrical fgt-vnffg2

sleep 10

# Generate FortiGate config file
spi_direct=$(ssh root@192.168.122.4 "ovs-ofctl -O openflow13 dump-flows br-int| grep nsp" | grep  -P -o 'nsp=(\K[0-9]*)'|sort -h|uniq|head -n1)
spi_reverse=$(ssh root@192.168.122.4 "ovs-ofctl -O openflow13 dump-flows br-int| grep nsp" | grep  -P -o 'nsp=(\K[0-9]*)'|sort -h|uniq|tail -n1)
echo ${spi_direct}
echo ${spi_reverse}
sed -e 's/<direct_spi_id_from_odl>/'${spi_direct}'/g' fgt-config.template > fgt-config
sed -i -e 's/<reverse_spi_id_from_odl>/'${spi_reverse}'/g' fgt-config

# Get Namespaces
mgmt_ns=$(ssh root@192.168.122.3 ip netns |head -n1)
private_ns=$(ssh root@192.168.122.3 ip netns |tail -n1)

# Load config in FortiGate
fgt_ip=$(openstack server list|grep fgt-nsh|awk '{print $10}'|grep -o -P '[0-9\.]*')
retries=30

while [ $retries -gt 0 ]
do
 # Temporarily disabled until FGT enabled ndiscforward setting. This causes immediate ICMPv6 ndisc packets
 cat fgt-config|ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${mgmt_ns} ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@${fgt_ip}
 #echo e
 if [ $? -ne 0 ]; then
   retries=$((retries-1))
   echo "Retrying loading config into FortiGate. Times left: $retries"
   sleep 5
 else
   break
 fi
 if [ $retries -lt 0 ]; then
   echo "Error: FortiGate does not seem to be up. Aborting"
   exit -1
 fi
done

# Set arps on client and server
client_mac=$(ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} ifconfig eth0  | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
server_mac=$(ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} ifconfig eth0  | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
echo ${client_mac}
echo ${server_mac}

ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} arp -s ${server_ip} ${server_mac}
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} arp -s ${client_ip} ${client_mac}

ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} arp -a
ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} arp -a

# Useful ssh commands
echo Access FortiGate CLI: 
echo ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${mgmt_ns} ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@${fgt_ip}

echo Access Client CLI:
echo ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} 

echo Access Second Server CLI:
echo ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} 
