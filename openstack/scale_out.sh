#!/bin/bash

set -x

if [ -z "$1" ]; then
  echo "Need id of the VM to SCALE"
  exit -1
fi

VM_ID=$1
F_IP_1="10.10.11.4"${VM_ID}


if [ -z "$2" ]; then
  echo "Need CIDR of the new chain"
  exit -1
fi
VM_ADDRESS=$2
VM_ADDRESS_IP=${VM_ADDRESS%%/*}

. env.sh

cat >env_${VM_ID}.sh <<EOF

source ~/nova.rc
source env.sh

VM_ID=${VM_ID}

floatIp_${VM_ID}_fgt=${F_IP_1}

openstack --insecure port list >port-list

p_A_fgt_${VM_ID}_id=\$(cat port-list|grep p_A_fgt_$VM_ID|awk '{print \$2}'|tr -d ' ')

p_B_fgt_${VM_ID}_id=\$(cat port-list|grep p_B_fgt_$VM_ID|awk '{print \$2}'|tr -d ' ')

EOF

cat >scale_in_${VM_ID}.sh <<EOF
set -x
source ~/nova.rc

VM_ID=${VM_ID}

floatIp_${VM_ID}_fgt=${F_IP_1}

openstack --insecure sfc port chain delete pc_${VM_ID}
openstack --insecure sfc flow classifier delete fc3_${VM_ID}
openstack --insecure sfc flow classifier delete fc2_${VM_ID}
openstack --insecure sfc flow classifier delete fc1_${VM_ID}

openstack --insecure sfc port pair group delete pg_${VM_ID}
openstack --insecure sfc port pair delete pp_${VM_ID}

openstack --insecure server delete fgt_${VM_ID}

openstack --insecure floating ip delete ${F_IP_1}

openstack --insecure port delete p_B_fgt_$VM_ID
openstack --insecure port delete p_A_fgt_$VM_ID

openstack --insecure network delete net_${VM_ID}_1
openstack --insecure network delete net_${VM_ID}_2

rm -f myConfig_${VM_ID}.txt
rm -f env_${VM_ID}
ssh-keygen -f ~/.ssh/known_hosts -R ${F_IP_1}
EOF

chmod 755 scale_in_${VM_ID}.sh

#Create ports of the proxy that will be part of the chain
openstack --insecure port create --network netM p_A_fgt_$VM_ID
openstack --insecure port create --network netServerM p_B_fgt_$VM_ID
. env_${VM_ID}.sh

#Create floating ips for management of proxy and FGT
floating_ip_fgt=floatIp_${VM_ID}_fgt
openstack --insecure floating ip create --floating-ip-address ${!floating_ip_fgt} ext_net

#Boot Proxy and FGT VMs
p_A_id=p_A_fgt_${VM_ID}_id
p_B_id=p_B_fgt_${VM_ID}_id
net_1=net_${VM_ID}_1
net_2=net_${VM_ID}_2

cat > myConfig_${VM_ID}.txt <<EOF
config system interface
  edit "port1"
    set mode dhcp
    set allowaccess https ping ssh http
    set mtu-override enable
    set mtu 1300
  next
  edit "port2"
      set mtu-override enable
      set mtu 1300
      set arpforward disable
  next
  edit "port3"
      set mtu-override enable
      set mtu 1300
      set arpforward disable
  next
end
config system virtual-wire-pair
    edit "vwp1"
        set member "port2" "port3"
    next
end
config firewall policy
  edit 1
    set name "vwp1-policy"
    set srcintf "port2" "port3"
    set dstintf "port2" "port3"
    set srcaddr "all"
    set dstaddr "all"
    set action accept
    set schedule "always"
    set service "ALL"
    set logtraffic all
    set logtraffic-start enable
  next
end
config system dns
  set primary 8.8.8.8
  set secondary 4.4.4.4
end

EOF


openstack --insecure server create --flavor m1.fortigate --image "FortiGate_vwp_mac_disable" --nic net-id=mgmt --nic port-id=${!p_A_id} --nic port-id=${!p_B_id} --config-drive true --user-data myConfig_${VM_ID}.txt fgt_${VM_ID}


retries=40
while [ $retries -gt 0 ]
do
  openstack --insecure server add floating ip fgt_${VM_ID} ${!floating_ip_fgt}
  result=$?
  if [ $result -eq 0 ] ; then
     break
  elif [ $retries -eq 1 ] ; then
     echo "FGT not ready. Aborting..."
     exit -1
  fi
  sleep 2
  retries=$((retries-1))
done

ssh-keygen -f ~/.ssh/known_hosts -R ${F_IP_1}

# Fix network namespaces, routes and arp tables

hexchars="0123456789ABCDEF"
end=$( for i in {1..6} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
MAC="00:00:11"$end

sshopts='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ssh $sshopts -i t1.pem ubuntu@$floatIpClient  "sudo ip netns add app_${VM_ID};" \
"sudo ip link add veth-app_${VM_ID} type veth peer name veth-br_${VM_ID};" \
"sudo ovs-vsctl add-port br-sfc veth-br_${VM_ID};" \
"sudo ip link set dev veth-br_${VM_ID} up;" \
"sudo ip link set veth-app_${VM_ID} netns app_${VM_ID};" \
"sudo ip netns exec app_${VM_ID} ifconfig veth-app_${VM_ID} ${VM_ADDRESS} up;" \
"sudo ip netns exec app_${VM_ID} ip link set dev veth-app_${VM_ID} addr ${MAC};" \
"sudo ip netns exec app_${VM_ID} arp -s ${pServerMip} $(grep pServerM port-list|awk -F '|' '{print $4}') -i veth-app_${VM_ID};" \
"sudo ip netns exec app_${VM_ID} ip link set dev veth-app_${VM_ID} up;" \
"sudo ip netns exec app_${VM_ID} ip link set dev lo up;" \
"sudo ip netns exec app_${VM_ID} ifconfig veth-app_${VM_ID} mtu 1400;" \
"sudo ip netns exec app_${VM_ID} ethtool -K veth-app_${VM_ID} tx off;" \
"sudo ip netns exec app_${VM_ID} ip route add ${pServerMip%.*}.0/24 dev veth-app_${VM_ID};" \
"sudo echo table=0,in_port=1,tcp,nw_src=${pServerMip}.0/32,nw_dst=${VM_ADDRESS%/*}/32,actions=mod_dl_dst:${MAC},NORMAL >flows${VM_ID}.txt; "\
"sudo ovs-ofctl -Oopenflow13 add-flows br-sfc flows${VM_ID}.txt"


ssh $sshopts -i t1.pem ubuntu@$floatIpServer "sudo arp -i eth1 -s ${VM_ADDRESS_IP} ${MAC} ;" \
"sudo ip route add ${VM_ADDRESS%.*/*}.0/24 dev eth1"



openstack --insecure sfc port pair create --ingress=${!p_A_id} --egress=${!p_B_id} pp_${VM_ID}
openstack --insecure sfc port pair group create --port-pair pp_${VM_ID} pg_${VM_ID}

openstack --insecure sfc flow classifier create --ethertype IPv4 --source-ip-prefix ${VM_ADDRESS_IP}/32  --destination-ip-prefix ${pServerMip}/24  --protocol tcp  --logical-source-port pClientM --logical-destination-port pServerM  fc1_${VM_ID}
openstack --insecure sfc flow classifier create --ethertype IPv4 --source-ip-prefix ${VM_ADDRESS_IP}/32  --destination-ip-prefix ${pServerMip}/24  --protocol udp  --logical-source-port pClientM --logical-destination-port pServerM  fc2_${VM_ID}
openstack --insecure sfc flow classifier create --ethertype IPv4 --source-ip-prefix ${VM_ADDRESS_IP}/32  --destination-ip-prefix ${pServerMip}/24  --protocol icmp  --logical-source-port pClientM --logical-destination-port pServerM fc3_${VM_ID}

neutron port-chain-create  --port-pair-group pgClientM --port-pair-group pg_${VM_ID} --port-pair-group pgServerM --flow-classifier fc1_${VM_ID} --flow-classifier fc2_${VM_ID} --flow-classifier fc3_${VM_ID} --chain-parameters symmetric=True pc_${VM_ID}

#openstack --insecure sfc port chain create --port-pair-group pgClientM --port-pair-group pg_${VM_ID} --port-pair-group pgServerM --flow-classifier fc1_${VM_ID} --flow-classifier fc2_${VM_ID} --flow-classifier fc3_${VM_ID} --chain-parameters symmetric=True pc_${VM_ID}

