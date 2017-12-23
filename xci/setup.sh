#!/usr/bin/env bash

set -x

. ~/openrc


# Install networking-sfc cli

pip freeze > previous_pip.txt
virtualenv nwsfc
. nwsfc/bin/activate
pip install networking-sfc

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


# Create networks

openstack network show mgmt||openstack network create mgmt
openstack subnet show mgmt_subnet||openstack subnet create --subnet-range 192.168.0.0/24 --network mgmt mgmt_subnet

openstack router show router-ext||openstack router create router-ext
openstack router add subnet router-ext mgmt_subnet
openstack router set --external-gateway ext-net router-ext


# Get images

wget http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
sudo apt install -y libguestfs-tools

sudo virt-sysprep -a trusty-server-cloudimg-amd64-disk1.img --root-password password:m \
    --delete /var/lib/cloud/* \
    --firstboot-command 'useradd -m -p "" m ; chage -d 0 m; ssh-keygen -A; rm -rf /var/lib/cloud/*;'

add "sed" for ssh configuration: root login and password login

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


openstack --insecure network create netM --disable-port-security #--provider-network-type vxlan
openstack --insecure subnet create --network netM --subnet-range 192.168.7.0/24 netM_subnet

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

openstack --insecure keypair create  t1 >t1.pem
chmod 600 t1.pem

openstack --insecure port create --network netM --fixed-ip ip-address=192.168.7.40 pClientM
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


openstack sfc --insecure port pair create --ingress=${pClientMid} --egress=${pClientMid} ppClientM
openstack sfc --insecure port pair create --ingress=${pServerMid} --egress=${pServerMid} ppServerM

openstack sfc --insecure port pair group create --port-pair ppClientM pgClientM
openstack sfc --insecure port pair group create --port-pair ppServerM pgServerM
