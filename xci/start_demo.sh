#!/usr/bin/env bash

set -x

. ~/openrc


# Install networking-sfc cli

#pip freeze > previous_pip.txt
#virtualenv nwsfc
#. nwsfc/bin/activate
#pip install networking-sfc

pip install -c https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=stable/pike networking-sfc==5.0.0


cat >env.sh <<EOF

source ~/openrc

floatIpClient="10.10.10.40"
floatIpServer="10.10.10.41"

openstack --insecure port list >port-list

pClientMid=\$(cat port-list|grep pClientM|awk -F '|' '{print \$2}'|tr -d ' ')
pClientMip=\$(cat port-list|grep pClientM|awk -F '|' '{print \$5}'|cut -d "'" -f2|tr -d ' ')

pServerMid=\$(cat port-list|grep pServerM|awk -F '|' '{print \$2}'|tr -d ' ')
pServerMip=\$(cat port-list|grep pServerM|awk -F '|' '{print \$5}'|cut -d "'" -f2|tr -d ' ')

EOF

openstack --insecure flavor create --ram 512 --disk 8 --vcpus 1 m1.smaller
openstack --insecure flavor create --ram 1024 --disk 3 --vcpus 1 --ephemeral 5 m1.fortigate

openstack --insecure network create netClientM --disable-port-security #--provider-network-type vxlan
openstack --insecure subnet create --network netClientM --subnet-range 192.168.7.0/24 netClientM_subnet

openstack --insecure network create netServerM --disable-port-security #--provider-network-type vxlan
openstack --insecure subnet create --network netServerM --subnet-range 192.168.7.0/24 netServerM_subnet



. env.sh
openstack --insecure floating ip create --floating-ip-address $floatIpClient ext-net
openstack --insecure floating ip create --floating-ip-address $floatIpServer ext-net



openstack --insecure port create --network netClientM --fixed-ip ip-address=192.168.7.40 pClientM
openstack --insecure port create --network netServerM --fixed-ip ip-address=192.168.7.41 pServerM
. env.sh

openstack server create --insecure --flavor m1.smaller --image "Trusty x86_64" --nic net-id=mgmt --nic port-id=$pClientMid --key-name t1 vmClientM
openstack server create --insecure --flavor m1.smaller --image "Trusty x86_64" --nic net-id=mgmt --nic port-id=$pServerMid --key-name t1 vmServerM

openstack --insecure server add floating ip vmClientM $floatIpClient
openstack --insecure server add floating ip vmServerM $floatIpServer


openstack sfc --insecure port pair create --ingress=${pClientMid} --egress=${pClientMid} ppClientM --service-function-parameters correlation=NSH
openstack sfc --insecure port pair create --ingress=${pServerMid} --egress=${pServerMid} ppServerM

openstack sfc --insecure port pair group create --port-pair ppClientM pgClientM
openstack sfc --insecure port pair group create --port-pair ppServerM pgServerM



#Create FortiGate

VM_ID="FGT1"

openstack --insecure port create --network netClientM p_A_fgt_$VM_ID
openstack --insecure port create --network netServerM p_B_fgt_$VM_ID

openstack --insecure port list >port-list
export p_A_fgt_${VM_ID}_id=$(cat port-list|grep p_A_fgt_$VM_ID|awk '{print $2}'|tr -d ' ')
export p_B_fgt_${VM_ID}_id=$(cat port-list|grep p_B_fgt_$VM_ID|awk '{print $2}'|tr -d ' ')

p_A_id=p_A_fgt_${VM_ID}_id
p_B_id=p_B_fgt_${VM_ID}_id

echo "Port A FGT ${VM_ID} Id: ${!p_A_id}"
echo "Port B FGT ${VM_ID} Id: ${!p_B_id}"

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

openstack --insecure image create --file ~/fortigate-5.6.3.qcow2 --public "FortiGate" --disk-format qcow2

openstack --insecure server create --flavor m1.fortigate --image "FortiGate" --nic net-id=mgmt --nic port-id=${!p_A_id} --nic port-id=${!p_B_id} --config-drive true --user-data myConfig_${VM_ID}.txt fgt_${VM_ID}



floatIpFgt="10.10.10.50"

openstack --insecure floating ip create --floating-ip-address $floatIpFgt ext-net
openstack --insecure server add floating ip fgt_${VM_ID} $floatIpFgt


#Create chain

openstack --insecure sfc port pair create --ingress=${!p_A_id} --egress=${!p_B_id} pp_${VM_ID}
openstack --insecure sfc port pair group create --port-pair pp_${VM_ID} pg_${VM_ID}

openstack --insecure sfc flow classifier create --ethertype IPv4 --source-ip-prefix ${pClientMip}/32  --destination-ip-prefix ${pServerMip}/24  --protocol tcp  --logical-source-port pClientM --logical-destination-port pServerM  fc1_${VM_ID}
openstack --insecure sfc flow classifier create --ethertype IPv4 --source-ip-prefix ${pClientMip}/32  --destination-ip-prefix ${pServerMip}/24  --protocol udp  --logical-source-port pClientM --logical-destination-port pServerM  fc2_${VM_ID}
openstack --insecure sfc flow classifier create --ethertype IPv4 --source-ip-prefix ${pClientMip}/32  --destination-ip-prefix ${pServerMip}/24  --protocol icmp  --logical-source-port pClientM --logical-destination-port pServerM fc3_${VM_ID}

# neutron port-chain-create
openstack sfc port chain create --port-pair-group pgClientM --port-pair-group pg_${VM_ID} --port-pair-group pgServerM --flow-classifier fc1_${VM_ID} --flow-classifier fc2_${VM_ID} --flow-classifier fc3_${VM_ID} --chain-parameters symmetric=True,correlation=None pc_${VM_ID}



#On each server:
sudo ifconfig eth1 up
sudo ip r add 192.168.7.0/24 dev eth1
sudo arp -s 192.168.7.41 fa:16:3e:30:e2:6e



#######
#
# Old
#
#######



cat > /etc/protocol <<EOF
tcp 6 TCP
udp 17 UDP
EOF

# External network

cd ~/releng-xci/xci/
ansible-playbook -i playbooks/inventory playbooks/prepare-tests.yml

cd ~

# Security Groups

openstack security group list|grep default|awk '{print $2}'|xargs -I[] openstack --insecure security group delete []

openstack security group rule create --proto tcp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 1:65535  --egress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --egress default || echo "should have been created already"

#Iptables to allow Inet Access from VMs

iptables -F
iptables -F -t nat
iptables -P FORWARD ACCEPT   ######
iptables -A POSTROUTING -t nat -j MASQUERADE

#Note interface has to be set to promiscuous mode to allow inet traffic in the vms
ifconfig br-vlan promisc

# Create networks

openstack network show mgmt||openstack network create mgmt
openstack subnet show mgmt_subnet||openstack subnet create --subnet-range 192.168.0.0/24 --network mgmt mgmt_subnet

openstack router show router-ext||openstack router create router-ext
openstack router add subnet router-ext mgmt_subnet
openstack router set --external-gateway ext-net router-ext

# Create keypair

openstack --insecure keypair create  t1 >t1.pem
chmod 600 t1.pem
openstack keypair show t1 --public-key>t1.pub

# Get images

wget http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
sudo apt install -y libguestfs-tools

sudo virt-sysprep -a trusty-server-cloudimg-amd64-disk1.img --root-password password:m \
    --delete /var/lib/cloud/* \
    --ssh-inject root:file:./t1.pub \
    --firstboot-command 'useradd -m -p "" m ; chage -d 0 m; ssh-keygen -A; rm -rf /var/lib/cloud/*;sed -i "s/PermitRootLogin .*/PermitRootLogin yes/" /etc/ssh/sshd_config; sed -i "s/PasswordAuthentication .*/PasswordAuthentication yes/" /etc/ssh/sshd_config;sed -i "s/nameserver .*/nameserver 8.8.8.8/" /etc/resolv.conf; service ssh restart'

openstack image show  "Trusty x86_64" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare --public  "Trusty x86_64"  --file  trusty-server-cloudimg-amd64-disk1.img

cat >env.sh <<EOF

source ~/openrc

floatIpClient="10.10.10.40"
floatIpServer="10.10.10.41"

openstack --insecure port list >port-list

pClientMid=\$(cat port-list|grep pClientM|awk -F '|' '{print \$2}'|tr -d ' ')
pClientMip=\$(cat port-list|grep pClientM|awk -F '|' '{print \$5}'|cut -d "'" -f2|tr -d ' ')

pServerMid=\$(cat port-list|grep pServerM|awk -F '|' '{print \$2}'|tr -d ' ')
pServerMip=\$(cat port-list|grep pServerM|awk -F '|' '{print \$5}'|cut -d "'" -f2|tr -d ' ')

EOF


openstack --insecure network create netClientM --disable-port-security #--provider-network-type vxlan
openstack --insecure subnet create --network netClientM --subnet-range 192.168.7.0/24 netClientM_subnet

openstack --insecure network create netServerM --disable-port-security #--provider-network-type vxlan
openstack --insecure subnet create --network netServerM --subnet-range 192.168.7.0/24 netServerM_subnet

openstack --insecure image create --file ~/cloud-images/mac-vwp-fortios.qcow2 --public "FortiGate.qcow2" --disk-format qcow2
#if [ $? -ne 0 ]; then
#  echo "Error uploading image"
#  exit -1
#fi

#qemu-img convert ~/cloud-images/mac-vwp-fortios.qcow2 ~/cloud-images/mac-vwp-fortios.raw
#openstack --insecure image create --file ~/cloud-images/mac-vwp-fortios.raw --public "FortiGate_vwp_mac_disable" --disk-format raw --container-format bare

openstack --insecure flavor create --ram 512 --disk 8 --vcpus 1 m1.smaller
openstack --insecure flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack --insecure flavor create --ram 1024 --disk 3 --vcpus 1 --ephemeral 5 m1.fortigate


. env.sh
openstack --insecure floating ip create --floating-ip-address $floatIpClient ext-net
openstack --insecure floating ip create --floating-ip-address $floatIpServer ext-net



openstack --insecure port create --network netClientM --fixed-ip ip-address=192.168.7.40 pClientM
openstack --insecure port create --network netServerM --fixed-ip ip-address=192.168.7.41 pServerM
. env.sh

openstack server create --insecure --flavor m1.smaller --image "Trusty x86_64" --nic net-id=mgmt --nic port-id=$pClientMid --key-name t1 vmClientM
openstack server create --insecure --flavor m1.smaller --image "Trusty x86_64" --nic net-id=mgmt --nic port-id=$pServerMid --key-name t1 vmServerM



retries=40
while [ $retries -gt 0 ]
do
  openstack --insecure server add floating ip vmClientM $floatIpClient && \
  openstack --insecure server add floating ip vmServerM $floatIpServer
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

retries=420
while [ $retries -gt 0 ]
do
  ssh $sshopts -i t1.pem root@$floatIpClient "ifconfig; sudo dhclient; sleep 2; ifconfig; sudo ethtool -K eth1 tx off;"
  result1=$?
  ssh $sshopts -i t1.pem root@$floatIpServer "ifconfig; sudo dhclient; sleep 2; ifconfig; sudo ethtool -K eth1 tx off;"
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

#Review security groups again. They are created twice
openstack security group list|grep default|awk '{print $2}'|xargs -I[] openstack --insecure security group delete []

openstack security group rule create --proto tcp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 1:65535  --egress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --egress default || echo "should have been created already"



ssh $sshopts -i t1.pem root@$floatIpClient "sudo sed -i \"s/nameserver .*/nameserver 8.8.8.8/\" /etc/resolv.conf; sudo apt update; sudo apt install -y openvswitch-switch;" \
 "sudo ovs-vsctl add-br br-sfc -- set bridge br-sfc protocols=OpenFlow10,OpenFlow12,OpenFlow13;" \
 "sudo ovs-vsctl add-port br-sfc eth1"


openstack sfc --insecure port pair create --ingress=${pClientMid} --egress=${pClientMid} ppClientM
openstack sfc --insecure port pair create --ingress=${pServerMid} --egress=${pServerMid} ppServerM

openstack sfc --insecure port pair group create --port-pair ppClientM pgClientM
openstack sfc --insecure port pair group create --port-pair ppServerM pgServerM


exit 0

# Final status of iptables in opnfv vm:

(openstack) (nwsfc) root@opnfv:~# iptables -S
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
-N DOCKER
-N DOCKER-ISOLATION
(nwsfc) root@opnfv:~# iptables -L
Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain DOCKER (0 references)
target     prot opt source               destination

Chain DOCKER-ISOLATION (0 references)
target     prot opt source               destination
(nwsfc) root@opnfv:~#






(nwsfc) root@opnfv:~# iptables -S -t nat
-P PREROUTING ACCEPT
-P INPUT ACCEPT
-P OUTPUT ACCEPT
-P POSTROUTING ACCEPT
-N DOCKER
-A POSTROUTING -j MASQUERADE
(nwsfc) root@opnfv:~# iptables -V -t nat
iptables v1.6.0
(nwsfc) root@opnfv:~# iptables -L -t nat
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination

Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
MASQUERADE  all  --  anywhere             anywhere

Chain DOCKER (0 references)
target     prot opt source               destination
(nwsfc) root@opnfv:~#





(nwsfc) root@opnfv:~# iptables -S -t filter
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
-N DOCKER
-N DOCKER-ISOLATION
(nwsfc) root@opnfv:~# iptables -L -t filter
Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain DOCKER (0 references)
target     prot opt source               destination

Chain DOCKER-ISOLATION (0 references)
target     prot opt source               destination
(nwsfc) root@opnfv:~#






(nwsfc) root@opnfv:~# iptables -S -t raw
-P PREROUTING ACCEPT
-P OUTPUT ACCEPT
(nwsfc) root@opnfv:~# iptables -L -t raw
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination
(nwsfc) root@opnfv:~#

(nwsfc) root@opnfv:~# iptables -S -t mangle
-P PREROUTING ACCEPT
-P INPUT ACCEPT
-P FORWARD ACCEPT
-P OUTPUT ACCEPT
-P POSTROUTING ACCEPT
(nwsfc) root@opnfv:~# iptables -L -t mangle
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination

Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain FORWARD (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
(nwsfc) root@opnfv:~#



