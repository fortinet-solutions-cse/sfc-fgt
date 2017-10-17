#!/bin/bash

if [ -z "$1" ]; then
  echo "Need name of the VM to SCALE"
  exit -1
fi

VM_NAME="ONE"

cat >env_${VM_NAME}.sh <<EOF

source ~/nova.rc

VM_NAME=${VM_NAME}

floatIp_${VM_NAME}_proxy="10.10.11.42"
floatIp_${VM_NAME}_fgt="10.10.11.43"

neutron port-list >port-list

p_A_proxy_${VM_NAME}_id=\$(cat port-list|grep p_A_proxy_$VM_NAME|awk '{print \$2}')
p_A_proxy_${VM_NAME}_ip=\$(cat port-list|grep p_A_proxy_$VM_NAME|awk '{print \$11}'|cut -d "\"" -f2)

p_B_proxy_${VM_NAME}_id=\$(cat port-list|grep p_B_proxy_$VM_NAME|awk '{print \$2}')
p_B_proxy_${VM_NAME}_ip=\$(cat port-list|grep p_B_proxy_$VM_NAME|awk '{print \$11}'|cut -d "\"" -f2)

EOF

#Create networks to communicate proxy with FGT
openstack network create net_${VM_NAME}_1 --provider-network-type vxlan --disable-port-security
openstack subnet create --network net_${VM_NAME}_1 --subnet-range 10.1.1.0/24 net_${VM_NAME}_1_subnet
openstack network create net_${VM_NAME}_2 --provider-network-type vxlan --disable-port-security
openstack subnet create --network net_${VM_NAME}_2 --subnet-range 10.1.1.0/24 net_${VM_NAME}_2_subnet

#Create ports of the proxy that will be part of the chain
openstack port create --network netM p_A_proxy_$VM_NAME
openstack port create --network netServerM p_B_proxy_$VM_NAME
. env_${VM_NAME}.sh


#Create floating ips for management of proxy and FGT
floating_ip_proxy=floatIp_${VM_NAME}_proxy
floating_ip_fgt=floatIp_${VM_NAME}_fgt
openstack floating ip create --floating-ip-address ${!floating_ip_proxy} ext_net
openstack floating ip create --floating-ip-address ${!floating_ip_fgt} ext_net




#Boot Proxy and FGT VMs
p_A_id=p_A_proxy_${VM_NAME}_id
p_B_id=p_B_proxy_${VM_NAME}_id
net_1=net_${VM_NAME}_1
net_2=net_${VM_NAME}_2



cat > myConfig_${VM_NAME}.txt <<EOF
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
  next
  edit "port3"
      set mtu-override enable
      set mtu 1300
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


nova boot --flavor m1.smaller --image "Trusty x86_64"  --nic net-name=mgmt --nic port-id=${!p_A_id} --nic port-id=${!p_B_id} --nic net-name=${net_1} --nic net-name=${net_2} --key-name t1 proxy_${VM_NAME}
nova boot --flavor m1.fortigate --image "FortiGate" --nic net-name=mgmt --nic net-name=${net_1} --nic net-name=${net_2} --config-drive true --user-data myConfig_${VM_NAME}.txt --ephemeral size=5 fgt_${VM_NAME}

openstack server add floating ip proxy_${VM_NAME} ${!floating_ip_proxy}
openstack server add floating ip fgt_${VM_NAME} ${!floating_ip_fgt}

alias ssh='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

retries=40
while [ $retries -gt 0 ]
do
  ssh -i t1.pem ubuntu@${!floating_ip_proxy} "ifconfig; sudo dhclient; sleep 2; ifconfig"
  result=$?
  if [ $result -eq 0 ] ; then
     break
  elif [ $retries -eq 1 ] ; then
     echo "Servers not ready. Aborting..."
     exit -1
  fi
  sleep 1
  retries=$((retries-1))
done

neutron port-pair-create --ingress=${!p_A_id} --egress=${!p_B_id} pp_${VM_NAME}
neutron port-pair-group-create --port-pair pp_${VM_NAME} pg_${VM_NAME}

neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix ${pClientMip}/24  --destination-ip-prefix ${pServerMip}/24  --protocol tcp  --logical-source-port pClientM fc1M
neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix ${pClientMip}/24  --destination-ip-prefix ${pServerMip}/24  --protocol udp  --logical-source-port pClientM fc2M
neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix ${pClientMip}/24  --destination-ip-prefix ${pServerMip}/24  --protocol icmp  --logical-source-port pClientM --logical-destination-port pServerM fc3M

neutron port-chain-create --port-pair-group pgClientM --port-pair-group pg_${VM_NAME} --port-pair-group pgServerM --flow-classifier fc1M --flow-classifier fc2M --flow-classifier fc3M --chain-parameters symmetric=True pc1M

# Inverted chain

#neutron port-pair-create --ingress=${!p_B_id} --egress=${!p_A_id}  pp_inv_${VM_NAME}
#neutron port-pair-group-create --port-pair pp_inv_${VM_NAME} pg_inv_${VM_NAME}

#neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix ${pServerMip}/24  --destination-ip-prefix ${pClientMip}/24  --protocol tcp  --logical-source-port pServerM fc1invM
#neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix ${pServerMip}/24  --destination-ip-prefix ${pClientMip}/24  --protocol udp  --logical-source-port pServerM fc2invM
#neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix ${pServerMip}/24  --destination-ip-prefix ${pClientMip}/24  --protocol icmp  --logical-source-port pServerM fc3invM

#neutron port-chain-create --port-pair-group pgServerM --port-pair-group pg_inv_${VM_NAME} --port-pair-group pgClientM --flow-classifier fc1invM --flow-classifier fc2invM --flow-classifier fc3invM pc1invM

ssh -i t1.pem ubuntu@${!floating_ip_proxy} "sudo apt update; \
sudo apt install -y python3-pip; \
sudo pip3 install hexdump; \
rm mac_changer.py*; \
wget https://raw.githubusercontent.com/fortinet-solutions-cse/sfc-proxy/mac_changer/mac_changer.py; \
chmod 755 mac_changer.py; \
sudo ethtool -K eth1 tx off; \
sudo ethtool -K eth2 tx off; \
sudo ethtool -K eth3 tx off; \
sudo ethtool -K eth4 tx off; \
sudo ifconfig eth1 promisc; \
sudo ifconfig eth2 promisc; \
sudo ifconfig eth3 promisc; \
sudo ifconfig eth4 promisc; \
sudo ifconfig eth1 mtu 4096; \
sudo ifconfig eth2 mtu 4096; \
sudo ifconfig eth3 mtu 4096; \
sudo ifconfig eth4 mtu 4096"

ssh -i t1.pem ubuntu@${!floating_ip_proxy} "sudo ./mac_changer.py -a eth1 -b eth2 -as eth3 -bs eth4"

rsync --progress ~/PycharmProjects/sfc-proxy/mac_changer.py fortinet@10.210.9.3:/home/fortinet/;ssh fortinet@10.210.9.3 "rsync -e 'ssh -i t1.pem' --progress mac_changer.py ubuntu@10.10.11.42:/home/ubuntu/"


