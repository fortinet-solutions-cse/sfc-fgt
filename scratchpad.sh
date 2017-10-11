
sudo ../PycharmProjects/nsh-proxy/proxy.py --encap_if vnet5 --unencap_in_if vnet10 --unencap_out_if vnet9
sudo /vagrant/proxy.py --encap_if eth0 --unencap_in_if eth2 --unencap_out_if eth1


ssh admin@192.168.122.40

#************************************************
# Start Fake FW
#************************************************
virsh destroy sf2
virsh undefine sf2

virt-install --connect qemu:///system --noautoconsole --filesystem ${PWD},shared_dir --import --name ${SF2_NAME} --ram 2024 --vcpus 1 --disk sf2.img,size=3 --disk ${SF2_NAME}-cidata.iso,device=cdrom --network bridge=virbr1,mac=${SF2_MAC}



rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -r -v --max-size=1048576 ./*  ${SF2_PROXY_IP}:/vagrant/

cp ../PycharmProjects/nsh-proxy/proxy.py .;rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -r -v --max-size=1048576 ./*  ${SF2_PROXY_IP}:/vagrant/;ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo nohup bash /vagrant/ovs/setup_sfc_proxy.sh 2>&1 >sf2proxy.log" &



config system interface
edit port1
set ip 192.168.122.40/24
end

config system interface
edit port2
set ip 192.168.60.40/24
end

config system vxlan
edit vxlan3
set vni 1
set remote-ip 192.168.160.70
set dstport 4789
set interface port3
end

config system vxlan
edit vxlan1
set vni 1
set remote-ip 192.168.60.70
set dstport 4789
set interface port2
end


config system vxlan
edit vxlan2
set vni 2
set remote-ip 192.168.170.70
set dstport 4789
set interface port3
end

config system interface
edit vxlan1
set ip 192.168.2.2/24
end

config system interface
edit vxlan2
set ip 192.168.2.1/24
end





diagnose sys vxlan fdb list vxlan1

diag sniffer packet port3


diag debug enable
diag debug flow filter add 192.168.7.12
#diag debug flow show console enable
diag debug flow trace start 100
diag debug enable


diag debug application httpsd -1 (FYI)

diagnose sniffer packet any 'dst port 80' 2 50 l

""""""""""
sudo brctl setageing virbr2 0
sudo brctl setageing virbr3 0

diagnose netlink brctl list
diagnose netlink brctl name host vwp1_v.b



config system settings
set multicast-skip-policy enable
end

config system interface
edit "port2"
set broadcast-forward enable
next


config firewall multicast-policy
edit 1
set action accept
next
end

config firewall multicast-policy
edit 1
set action accept
set srcintf port2
set dstintf port2
set srcaddr 0.0.0.0
set dstaddr 0.0.0.0
next
end


config system session-ttl
   set default 0
     config port
       edit 443
         set protocol 6
         set timeout 3600
         set end-port 443
         set start-port 443
        next
      end
end

""""""""""""

config system interface
edit "port2"
set broadcast-forward enable
next
end


FortiGate-VM64-KVM (vxlan1) # 0800
                                  IP Version: 4 IP Header Length: 5, TTL: 64, Protocol: 17, Src IP: 192.168.60.50, Dst IP: 192.168.60.70
                           UDP Src Port: 49289, Dst Port: 4790, Length: 152, Checksum: 41913
                                                                                            VxLAN/VxLAN-gpe VNI: 0, flags: 0c, Next: 3
                         NSH base nsp: 37, nsi: 253
                                                   NSH context c1: 0x00000004, c2: 0x00000000, c3: 0xc0a83c28, c4: 0x00000000


Received Packet #79
   Eth Dst MAC: 08:00:27:4c:60:70, Src MAC: 08:00:27:4c:60:40, Ethertype: 0x0800
   IP Version: 4 IP Header Length: 5, TTL: 64, Protocol: 17,
   Src IP: 192.168.60.40, Dst IP: 192.168.60.70
   UDP Src Port: 4789, Dst Port: 4789, Length: 58, Checksum: 19303
   VxLAN/VxLAN-gpe VNI: 1, flags: 08, Next: 0
   NSH base nsp: 16777134, nsi: 101
   NSH context c1: 0x75cf3564, c2: 0x08060001, c3: 0x08000604, c4: 0x0001ae65
                                                                                                 sf_ip = 8.0.6.4




cat >test <<EOF
<network>
  <name>test</name>
  <bridge name='test' stp='off' delay='0'/>
  <mac address='52:54:00:79:34:17'/>
  <ip address='192.168.90.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.90.2' end='192.168.90.254'/>
      <host mac='00:22:33:44:55:10' name='tap1' ip='192.168.90.10'/>
      <host mac='00:22:33:44:55:20' name='tap2' ip='192.168.90.20'/>
    </dhcp>
  </ip>
</network>
EOF

sudo virsh net-create test


sudo wireshark -i vnet9 &
sudo wireshark -i vnet7 &
sudo wireshark -i vnet8 &
sudo wireshark -i vnet10 &


sudo wireshark -i vnet5 &



virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name sff2 --file sff2.img --mac=${SFF2_MAC}
sudo virt-sysprep -a sff2.img --hostname sff2 --firstboot-command 'sudo ssh-keygen -A'




VM_NAME=sff2
   virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${VM_NAME} --file ${VM_NAME}.img --mac=${VM_MAC[${VM_NAME}]}
   if [ $? -ne 0 ]; then
     echo "Error cloning image. Aborting"
     exit -1
   fi

   sleep 3

   sudo virt-sysprep -a ${VM_NAME}.img --hostname ${VM_NAME} --firstboot-command 'sudo ssh-keygen -A'

   cat >meta-data <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

   rm -rf ${VM_NAME}-cidata.iso
   genisoimage -output ${VM_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
   chmod 666 ${VM_NAME}-cidata.iso

   virsh change-media ${VM_NAME} hdb --eject --config --force
   virsh change-media ${VM_NAME} hdb ${PWD}/${VM_NAME}-cidata.iso --insert --config --force






diagnose sniffer packet any 'dst port 80' 2 50 l
diagnose sniffer packet port2
diagnose sniffer packet port3


diag debug flow filter add 192.168.7.10
diag debug flow filter dport 80
diag debug flow show function-name enable
diag debug flow show iprope enable
diag debug flow trace start 100

diag debug enable

Backup:

config system global
set admin-scp enable
end

scp admin@x.x.x.5:sys_config ./

#===========================
#Install VNC Server
#===========================
sudo apt install -y xfce4 xfce4-goodies tightvncserver xfonts-base
vncserver
vncserver -kill :1
mv ~/.vnc/xstartup ~/.vnc/xstartup.bak

cat > ~/.vnc/xstartup <<EOF
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF
sudo chmod +x ~/.vnc/xstartup
vncserver
grep 59.. ~/.vnc/*.log

#===========================
#Configure OpenStack
#===========================

NEUTRON_EXT_NET_GW="10.10.10.1"
NEUTRON_EXT_NET_CIDR="10.10.10.0/24"

NEUTRON_EXT_NET_NAME="ext_net" # Unused
NEUTRON_DNS=$NEUTRON_EXT_NET_GW
NEUTRON_FLOAT_RANGE_START="10.10.10.12"
NEUTRON_FLOAT_RANGE_END="10.10.10.253"

NEUTRON_FIXED_NET_CIDR="192.168.16.0/22"

# Determine the tenant id for the configured tenant name.
export TENANT_ID="$(openstack project list | grep $OS_TENANT_NAME | awk '{ print $2 }')"

if [ "$TENANT_ID" = "" ]; then
	echo "Unable to find tenant ID, keystone auth problem"
	exit 2
fi

echo "Configuring Openstack Neutron Networking"

#neutron net-show ext_net > /dev/null 2>&1 || neutron net-create ext_net --tenant-id $TENANT_ID -- --router:external=True
#EXTERNAL_NETWORK_ID=$(neutron net-show ext_net | grep " id" | awk '{print $4}')
#neutron subnet-show ext_net_subnet > /dev/null 2>&1 || neutron subnet-create ext_net $NEUTRON_EXT_NET_CIDR --name ext_net_subnet --tenant-id $TENANT_ID \
#--allocation-pool start=$NEUTRON_FLOAT_RANGE_START,end=$NEUTRON_FLOAT_RANGE_END \
#--gateway $NEUTRON_EXT_NET_GW --disable-dhcp --dns_nameservers $NEUTRON_DNS list=true


openstack network create --share --external --disable-port-security --provider-physical-network flat --provider-network-type flat ext_net
openstack subnet create --network ext_net \
  --allocation-pool start=$NEUTRON_FLOAT_RANGE_START,end=$NEUTRON_FLOAT_RANGE_END \
  --dns-nameserver $NEUTRON_DNS --gateway $NEUTRON_EXT_NET_GW \
  --subnet-range $NEUTRON_EXT_NET_CIDR ext_net_subnet

#Create mgmt network for neutron for tenant VMs
#neutron net-show mgmt > /dev/null 2>&1 || neutron net-create mgmt
#neutron subnet-show mgmt_subnet > /dev/null 2>&1 || neutron subnet-create mgmt $NEUTRON_FIXED_NET_CIDR -- --name mgmt_subnet --dns_nameservers list=true $NEUTRON_DNS
#SUBNET_ID=$(neutron subnet-show mgmt_subnet | grep " id" | awk '{print $4}')

openstack network create --disable-port-security mgmt
openstack subnet create --network mgmt \
  --subnet-range $NEUTRON_FIXED_NET_CIDR mgmt_subnet



#Create router for external network and mgmt network
neutron router-show provider-router > /dev/null 2>&1 || neutron router-create --tenant-id $TENANT_ID provider-router
ROUTER_ID=$(neutron router-show provider-router | grep " id" | awk '{print $4}')
neutron router-gateway-clear provider-router || true
neutron router-gateway-set $ROUTER_ID $EXTERNAL_NETWORK_ID
## make it always ok to have it indempodent.
neutron router-interface-add $ROUTER_ID $SUBNET_ID || true

openstack router create provider-router
openstack router set --external-gateway ext_net provider-router
openstack router add subnet provider-router mgmt_subnet


#Configure the default security group to allow ICMP and SSH
openstack security group rule create --proto icmp default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 22 default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 80 default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 443 default || echo "should have been created already"
#port for RDP
openstack security group rule create --proto tcp --dst-port 3389 default || echo "should have been created already"


##make wide open
openstack security group rule create --proto tcp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 1:65535  --egress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --egress default || echo "should have been created already"


#Remove the m1.tiny as it is too small for Ubuntu.
for flavor in m1.tiny m1.small m1.medium m1.large m1.xlarge
do
openstack  flavor delete $flavor || true
done
openstack flavor create m1.small --id auto --ram 1024 --disk 20 --vcpus 1
openstack flavor create m1.medium --id auto --ram 2048 --disk 20 --vcpus 2
openstack flavor create m1.large --id auto --ram 4096 --disk 20 --vcpus 4

#Modify quotas for the tenant to allow large deployments
openstack quota  set --ram 204800 --cores 200 --instances 100 admin
neutron quota-update --security-group 100 --security-group-rule 500



echo "Uploading images to glance"

#Upload images to glance
folder=$HOME/cloud-images

wget http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
openstack image show  "Trusty x86_64" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare --public  "Trusty x86_64"  --file  $folder/trusty-server-cloudimg-amd64-disk1.img
openstack image show  "Centos 7 x86_64" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare  --public  "Centos 7 x86_64"  --file  $folder/CentOS-7-x86_64-GenericCloud.qcow2
openstack image show  "Cirros 0.3.4" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare  --public  "Cirros 0.3.4"  --file  $folder/cirros-0.3.4-x86_64-disk.img


(Note: When doing forwarding of ports, include 6082 for vnc)



#===========================
#Networking SFC commands
#===========================


cat >env.sh <<EOF

source ~/nova.rc

floatIp1="10.10.11.40"
floatIp2="10.10.11.41"
floatIp3="10.10.11.42"
floatIp4="10.10.11.43"

neutron port-list >port-list

p1Mid=\$(cat port-list|grep p1M|awk  '{print \$2}')
p2Mid=\$(cat port-list|grep p2M|awk  '{print \$2}')
p3Mid=\$(cat port-list|grep p3M|awk  '{print \$2}')
p4Mid=\$(cat port-list|grep p4M|awk  '{print \$2}')
p5Mid=\$(cat port-list|grep p5M|awk  '{print \$2}')
p6Mid=\$(cat port-list|grep p6M|awk  '{print \$2}')

p1Mip=\$(cat port-list|grep p1M|awk '{print \$11}'|cut -d "\"" -f2)
p2Mip=\$(cat port-list|grep p2M|awk '{print \$11}'|cut -d "\"" -f2)
p3Mip=\$(cat port-list|grep p3M|awk '{print \$11}'|cut -d "\"" -f2)
p4Mip=\$(cat port-list|grep p4M|awk '{print \$11}'|cut -d "\"" -f2)
p5Mip=\$(cat port-list|grep p5M|awk '{print \$11}'|cut -d "\"" -f2)
p6Mip=\$(cat port-list|grep p6M|awk '{print \$11}'|cut -d "\"" -f2)

#p1Mip=\$(openstack port show \$p1Mid |grep ip_address=|cut -d"'" -f2)
#p2Mip=\$(openstack port show \$p2Mid |grep ip_address=|cut -d"'" -f2)
#p3Mip=\$(openstack port show \$p3Mid |grep ip_address=|cut -d"'" -f2)
#p4Mip=\$(openstack port show \$p4Mid |grep ip_address=|cut -d"'" -f2)
#p5Mip=\$(openstack port show \$p5Mid |grep ip_address=|cut -d"'" -f2)
#p6Mip=\$(openstack port show \$p6Mid |grep ip_address=|cut -d"'" -f2)

EOF

openstack network create netM --provider-network-type vxlan --disable-port-security
openstack subnet create --network netM --subnet-range 192.168.7.0/24 netM_subnet

openstack network create netServerM --provider-network-type vxlan --disable-port-security
openstack subnet create --network netServerM --subnet-range 192.168.30.0/24 netServerM_subnet

#--no-dhcp

openstack image create --file fortios.qcow2 --public "FortiGate" --disk-format qcow2 --container-format bare
#openstack image create --disk-format qcow2 --container-format bare --public  "Trusty x86_64"  --file  trusty-server-cloudimg-amd64-disk1.img

. env.sh
openstack floating ip create --floating-ip-address $floatIp1 ext_net
openstack floating ip create --floating-ip-address $floatIp2 ext_net
openstack floating ip create --floating-ip-address $floatIp3 ext_net
openstack floating ip create --floating-ip-address $floatIp4 ext_net

openstack port create --network netM p1M
openstack port create --network netM p2M
openstack port create --network netM p3M
openstack port create --network netM p4M
openstack port create --network netServerM p5M
openstack port create --network netServerM p6M
. env.sh

#neutron port-create --name p1M --port_security_enabled=False --no-security-groups netM
#neutron port-create --name p2M --port_security_enabled=False --no-allowed-address-pairs --no-security-groups netM
#neutron port-create --name p3M --port_security_enabled=False --no-allowed-address-pairs --no-security-groups netM
#neutron port-create --name p4M --port_security_enabled=False --no-allowed-address-pairs --no-security-groups netM
#neutron port-create --name p5M --port_security_enabled=False --no-allowed-address-pairs --no-security-groups netM
#neutron port-create --name p6M --port_security_enabled=False --no-security-groups netM
#. env.sh

openstack keypair create  t1 >t1.pem
chmod 600 t1.pem

openstack flavor create --ram 512 --disk 8 --vcpus 1 m1.smaller
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny
openstack flavor create --ram 1024 --disk 3 --vcpus 1 --ephemeral 5 m1.fortigate

cat > myConfig1.txt <<EOF
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

cat > myLicense1.txt <<EOF
-----BEGIN FGT VM LICENSE-----
QAAAAOb1gAZanLrL9DtwE2uco7+HgNar1v7XZACUth+ozcpsBaXhpbtEY+LKdu6B
rz4yjSjB2ehyK9ptF6v94/9HdH1gAAAAK0wVywB9LLXLfbkyYJZaqXjsSsW8/z+6
RN7iveOxB9ZdyaXAz1XLRHKOez/bQb/7EesChwc0uePHOXwlhyQvbD0c92tyk5Dp
lU80JbM2lKQ0GsBsOWsJt6FWRqYV+jQT
-----END FGT VM LICENSE-----
EOF

cat > myConfig2.txt <<EOF
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
EOF

nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$p1Mid --key-name t1 vm1M
#nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$p2Mid --nic port-id=$p3Mid --key-name t1 vm2M
nova boot --flavor m1.fortigate --image "FortiGate" --nic net-name=mgmt --nic port-id=$p2Mid --nic port-id=$p3Mid --config-drive true --user-data myConfig1.txt --ephemeral size=5 --file license=myLicense1.txt vm2M
#nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$p4Mid --nic port-id=$p5Mid --key-name t1 vm3M
nova boot --flavor m1.fortigate --image "FortiGate" --nic net-name=mgmt --nic port-id=$p4Mid --nic port-id=$p5Mid --config-drive true --user-data myConfig2.txt --ephemeral size=5 vm3M
nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$p6Mid --key-name t1 vm4M


nova boot --flavor m1.smaller --image "Trusty x86_64"  --nic net-name=mgmt --nic port-id=$p2Mid --nic port-id=$p3Mid --key-name t1 vm2M
nova boot --flavor m1.smaller --image "Trusty x86_64"  --nic net-name=mgmt --nic port-id=$p4Mid --nic port-id=$p5Mid --key-name t1 vm3M

openstack server add floating ip vm1M $floatIp1
openstack server add floating ip vm2M $floatIp2
openstack server add floating ip vm3M $floatIp3
openstack server add floating ip vm4M $floatIp4

#nova floating-ip-associate vm1M $floatIp1
#nova floating-ip-associate vm2M $floatIp2
#nova floating-ip-associate vm3M $floatIp3
#nova floating-ip-associate vm4M $floatIp4



#neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix $p1Mip/24  --destination-ip-prefix $p6Mip/24  --protocol tcp  --source-port 23:65535  --destination-port 80:80 --logical-source-port p1M fc1M
neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix $p1Mip/24  --destination-ip-prefix $p6Mip/24  --protocol tcp  --logical-source-port p1M fc1M
neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix $p1Mip/24  --destination-ip-prefix $p6Mip/24  --protocol udp  --logical-source-port p1M fc2M
neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix $p1Mip/24  --destination-ip-prefix $p6Mip/24  --protocol icmp  --logical-source-port p1M fc3M


neutron port-pair-create --ingress=p2M --egress=p3M pp1M
neutron port-pair-create --ingress=p4M --egress=p5M pp2M

neutron port-pair-group-create --port-pair pp1M pg1M
neutron port-pair-group-create --port-pair pp2M pg2M

neutron port-chain-create --port-pair-group pg1M --port-pair-group pg2M --flow-classifier fc1M --flow-classifier fc2M --flow-classifier fc3M pc1M

ssh -i t1.pem ubuntu@$floatIp1
ssh -i t1.pem ubuntu@$floatIp2
ssh -i t1.pem ubuntu@$floatIp3
ssh -i t1.pem ubuntu@$floatIp4

ifconfig; sudo dhclient; ifconfig

#In VM2 and VM3
sudo apt install -y python3-pip
sudo pip3 install hexdump
wget https://raw.githubusercontent.com/fortinet-solutions-cse/sfc-proxy/simple_replier/simple_replier.py
sudo python3 simple_replier.py -a eth1 -b eth2

#Arp entry to avoid arp loops
ssh -i t1.pem ubuntu@10.10.11.40 "sudo arp -i eth1 -s $p6Mip $(grep p6M port-list|awk '{print $6}')"
ssh -i t1.pem ubuntu@10.10.11.43 "sudo arp -i eth1 -s $p1Mip $(grep p1M port-list|awk '{print $6}')"

ssh -i t1.pem ubuntu@10.10.11.40 "sudo ip route add $p6Mip/24 dev eth1 proto kernel scope link src $p1Mip"


#===========================
# Status
#===========================


neutron subnet-list
neutron net-list

nova list
nova show vm1M
nova show vm2M
nova show vm3M
nova show vm4M

neutron flow-classifier-list
neutron port-pair-list
neutron port-pair-group-list
neutron port-chain-list
neutron port-list

openstack floating ip list

openstack flavor list

glance image-list

#===========================
# Deletion
#===========================

neutron port-chain-delete pc1M

neutron port-pair-group-delete pg2M
neutron port-pair-group-delete pg1M

neutron port-pair-delete pp2M
neutron port-pair-delete pp1M

neutron flow-classifier-delete fc1M
neutron flow-classifier-delete fc2M
neutron flow-classifier-delete fc3M

nova delete vm4M
nova delete vm3M
nova delete vm2M
nova delete vm1M

neutron port-delete p6M
neutron port-delete p5M
neutron port-delete p4M
neutron port-delete p3M
neutron port-delete p2M
neutron port-delete p1M

openstack subnet delete netM_subnet
openstack network delete netM
openstack subnet delete netServerM_subnet
openstack network delete netServerM

openstack flavor delete m1.tiny
openstack flavor delete m1.smaller

openstack floating ip delete $floatIp1
openstack floating ip delete $floatIp2
openstack floating ip delete $floatIp3
openstack floating ip delete $floatIp4

openstack keypair delete  t1

glance image-delete $(glance image-list|grep FortiGate|awk '{print $2}')

openstack flavor delete m1.fortigate

rm t1.pem
rm myConfig1.txt
rm myConfig2.txt

ssh-keygen -f "/home/fortinet/.ssh/known_hosts" -R $floatIp1
ssh-keygen -f "/home/fortinet/.ssh/known_hosts" -R $floatIp2
ssh-keygen -f "/home/fortinet/.ssh/known_hosts" -R $floatIp3
ssh-keygen -f "/home/fortinet/.ssh/known_hosts" -R $floatIp4




--- Scratch ---

nova boot --flavor m1.tiny --image "Cirros 0.3.4" --nic net-name=netM --key-name t1 testVM
nova boot --flavor m1.medium --image "Trusty x86_64" --nic net-name=netM --key-name t1 test2VM


