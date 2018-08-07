
if [ ! -f openrc ]; then
    echo "openrc file not found!"
fi

set -x

source openrc

server_ip=$(openstack server list|grep server|awk '{print $8}'|grep -o -P '[0-9\.]*')
client_ip=$(openstack server list|grep client|awk '{print $8}'|grep -o -P '[0-9\.]*')
fgt_ip=$(openstack server list|grep fgt-nsh|awk '{print $10}'|grep -o -P '[0-9\.]*')

server_port=$(openstack port list|grep $server_ip|awk '{print $2}') 
client_port=$(openstack port list|grep $client_ip|awk '{print $2}') 

spi_direct=$(ssh root@192.168.122.4 "ovs-ofctl -O openflow13 dump-flows br-int| grep nsp" | grep  -P -o 'nsp=(\K[0-9]*)'|sort -h|uniq|head -n1)
spi_reverse=$(ssh root@192.168.122.4 "ovs-ofctl -O openflow13 dump-flows br-int| grep nsp" | grep  -P -o 'nsp=(\K[0-9]*)'|sort -h|uniq|tail -n1)

mgmt_ns=$(ssh root@192.168.122.3 ip netns |head -n1)
private_ns=$(ssh root@192.168.122.3 ip netns |tail -n1)

client_mac=$(ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} ifconfig eth0  | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')
server_mac=$(ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} ifconfig eth0  | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}')

echo Access FortiGate CLI: 
echo ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${mgmt_ns} ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@${fgt_ip}

echo Access Client CLI:
echo ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${client_ip} 

echo Access Server CLI:
echo ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@192.168.122.3 ip netns exec ${private_ns} sshpass -p opnfv ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${server_ip} 
