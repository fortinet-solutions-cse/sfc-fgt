#!/bin/bash

set -x
source env.sh

sudo echo "Please input sudo password for later commands:"

#************************************************
# Ensure there is a generated public key
#************************************************
if [ ! -f ${HOME}/.ssh/id_rsa.pub ]; then 
  echo "Need ${HOME}/.ssh/id_rsa.pub generated. Do ssh-keygen"
  exit -1
fi

#************************************************
# Download base image, trusty 14.04, cloud based
#************************************************
UBUNTU_IMAGE_URL=https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
UBUNTU_IMAGE_NAME=$(basename ${UBUNTU_IMAGE_URL})
if [ ! -e ${UBUNTU_IMAGE_NAME} ]; then 
   wget ${UBUNTU_IMAGE_URL}
fi


#************************************************
# Clean previous installations in virsh
#************************************************
virsh destroy ${CLASSIFIER1_NAME}
virsh undefine ${CLASSIFIER1_NAME}
rm -f ${CLASSIFIER1_NAME}.img
rm -f ${CLASSIFIER1_NAME}-cidata.iso

virsh destroy ${CLASSIFIER2_NAME}
virsh undefine ${CLASSIFIER2_NAME}
rm -f ${CLASSIFIER2_NAME}.img
rm -f ${CLASSIFIER2_NAME}-cidata.iso

virsh destroy ${SFF1_NAME}
virsh undefine ${SFF1_NAME}
rm -f ${SFF1_NAME}.img
rm -f ${SFF1_NAME}-cidata.iso

virsh destroy ${SFF2_NAME}
virsh undefine ${SFF2_NAME}
rm -f ${SFF2_NAME}.img
rm -f ${SFF2_NAME}-cidata.iso

virsh destroy ${SF1_NAME}
virsh undefine ${SF1_NAME}
rm -f ${SF1_NAME}.img
rm -f ${SF1_NAME}-cidata.iso

virsh destroy ${SF2_NAME}
virsh undefine ${SF2_NAME}
rm -f ${SF2_NAME}.img
rm -f ${SF2_NAME}-cidata.iso

virsh destroy ${SF2_PROXY_NAME}
virsh undefine ${SF2_PROXY_NAME}
rm -f ${SF2_PROXY_NAME}.img
rm -f ${SF2_PROXY_NAME}-cidata.iso

rm -f user-data
rm -f meta-data
rm -f virbr1

virsh net-destroy virbr1

#************************************************
# Prepare data for virsh network
#************************************************
cat >virbr1 <<EOF
<network>
  <name>virbr1</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr1' stp='on' delay='0'/>
  <mac address='52:54:00:79:7c:c3'/>
  <ip address='192.168.60.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.60.2' end='192.168.60.254'/>
      <host mac='${CLASSIFIER1_MAC}' name='${CLASSIFIER1_NAME}' ip='${CLASSIFIER1_IP}'/>
      <host mac='${CLASSIFIER2_MAC}' name='${CLASSIFIER2_NAME}' ip='${CLASSIFIER2_IP}'/>
      <host mac='${SFF1_MAC}' name='${SFF1_NAME}' ip='${SFF1_IP}'/>
      <host mac='${SFF2_MAC}' name='${SFF2_NAME}' ip='${SFF2_IP}'/>
      <host mac='${SF1_MAC}' name='${SF1_NAME}' ip='${SF1_IP}'/>
      <host mac='${SF2_MAC}' name='${SF2_NAME}' ip='${SF2_IP}'/>
      <host mac='${SF2_PROXY_MAC}' name='${SF2_PROXY_NAME}' ip='${SF2_PROXY_IP}'/>
    </dhcp>
  </ip>
</network>
EOF
sudo virsh net-create virbr1

#************************************************
# Prepare data for cloud init
#************************************************
cat >meta-data <<EOF
instance-id: ${CLASSIFIER1_NAME}
local-hostname: ${CLASSIFIER1_NAME}
EOF

cat >user-data <<EOF
#cloud-config
users:
  - name: ${USER}
    gecos: Host User Replicated
    passwd: 4096$WZV/rmpx9X$M0ZfYfQookX7TXTBf64j31kvRZu3HNPESAVpv8B61qVW89oI86HB2Ihs9pAUrHTvnigdgvUJdBoAaLSG2L0Vi0
    ssh-authorized-keys:
      - $(cat ${HOME}/.ssh/id_rsa.pub)
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
EOF


rm -rf ${CLASSIFIER1_NAME}-cidata.iso
genisoimage -output ${CLASSIFIER1_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data



sudo cp ubuntu-14.04-server-cloudimg-amd64-disk1.img ${CLASSIFIER1_NAME}.img
sudo virt-sysprep -a ${CLASSIFIER1_NAME}.img --root-password password:m \
    --firstboot-command 'useradd -m -p "" vagrant ; chage -d 0 vagrant'

virt-install --connect qemu:///system --noautoconsole --filesystem ${PWD},shared_dir --import --name ${CLASSIFIER1_NAME} --ram 2048 --vcpus 1 --disk ${CLASSIFIER1_NAME}.img,size=3 --disk ${CLASSIFIER1_NAME}-cidata.iso,device=cdrom --network bridge=virbr1,mac=${CLASSIFIER1_MAC}

ssh-keygen -R ${CLASSIFIER1_IP}
alias ssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

until ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo mkdir /vagrant/"
do
  sleep 1
  echo "."
done

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo chmod 777 /vagrant/"

rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -r -v --max-size=1048576 ./*  ${CLASSIFIER1_IP}:/vagrant/


#************************************************
# Install OVS on classifier1
#************************************************

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo /vagrant/ovs/install_ovs.sh"
if [ $? -ne 0 ] ; then
   echo "Failed to install ovs on ${CLASSIFIER1_NAME}"
   exit -1
fi

#************************************************
#************************************************
#************************************************
#************************************************
#FIX THIS!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo rm /home/m/dpdk-16.07.tar.xz"
#************************************************
#************************************************
#************************************************
#************************************************
#************************************************



ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "echo HI_THERE>HI_THERE.txt"

#************************************************
# Stop base vm for cloning
#************************************************
sleep 60

virsh destroy ${CLASSIFIER1_NAME}

sleep 60

#************************************************
# Clone images for the rest of entities: CLASSIFIER2
#************************************************

virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${CLASSIFIER2_NAME} --file ${CLASSIFIER2_NAME}.img --mac=${CLASSIFIER2_MAC} 
if [ $? -ne 0 ]; then
  echo "Error cloning image. Aborting"
  exit -1
fi

sleep 3

sudo virt-sysprep -a ${CLASSIFIER2_NAME}.img --hostname ${CLASSIFIER2_NAME} --firstboot-command 'sudo ssh-keygen -A' 

cat >meta-data <<EOF
instance-id: ${CLASSIFIER2_NAME}
local-hostname: ${CLASSIFIER2_NAME}
EOF
rm -rf ${CLASSIFIER2_NAME}-cidata.iso
genisoimage -output ${CLASSIFIER2_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
chmod 666 ${CLASSIFIER2_NAME}-cidata.iso

virsh change-media ${CLASSIFIER2_NAME} hdb --eject --config --force
virsh change-media ${CLASSIFIER2_NAME} hdb ${PWD}/${CLASSIFIER2_NAME}-cidata.iso --insert --config --force

#************************************************
# Clone images for the rest of entities: SFF1
#************************************************

virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${SFF1_NAME} --file ${SFF1_NAME}.img --mac=${SFF1_MAC} 
if [ $? -ne 0 ]; then
  echo "Error cloning image. Aborting"
  exit -1
fi

sleep 3

sudo virt-sysprep -a ${SFF1_NAME}.img --hostname ${SFF1_NAME} --firstboot-command 'sudo ssh-keygen -A' 

cat >meta-data <<EOF
instance-id: ${SFF1_NAME}
local-hostname: ${SFF1_NAME}
EOF
rm -rf ${SFF1_NAME}-cidata.iso
genisoimage -output ${SFF1_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
chmod 666 ${SFF1_NAME}-cidata.iso

virsh change-media ${SFF1_NAME} hdb --eject --config --force
virsh change-media ${SFF1_NAME} hdb ${PWD}/${SFF1_NAME}-cidata.iso --insert --config --force

#************************************************
# Clone images for the rest of entities: SFF2
#************************************************

virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${SFF2_NAME} --file ${SFF2_NAME}.img --mac=${SFF2_MAC} 
if [ $? -ne 0 ]; then
  echo "Error cloning image. Aborting"
  exit -1
fi

sleep 3

sudo virt-sysprep -a ${SFF2_NAME}.img --hostname ${SFF2_NAME} --firstboot-command 'sudo ssh-keygen -A' 

cat >meta-data <<EOF
instance-id: ${SFF2_NAME}
local-hostname: ${SFF2_NAME}
EOF
rm -rf ${SFF2_NAME}-cidata.iso
genisoimage -output ${SFF2_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
chmod 666 ${SFF2_NAME}-cidata.iso

virsh change-media ${SFF2_NAME} hdb --eject --config --force
virsh change-media ${SFF2_NAME} hdb ${PWD}/${SFF2_NAME}-cidata.iso --insert --config --force

#************************************************
# Clone images for the rest of entities: SF1
#************************************************

virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${SF1_NAME} --file ${SF1_NAME}.img --mac=${SF1_MAC} 
if [ $? -ne 0 ]; then
  echo "Error cloning image. Aborting"
  exit -1
fi

sleep 3

sudo virt-sysprep -a ${SF1_NAME}.img --hostname ${SF1_NAME} --firstboot-command 'sudo ssh-keygen -A' 

cat >meta-data <<EOF
instance-id: ${SF1_NAME}
local-hostname: ${SF1_NAME}
EOF
rm -rf ${SF1_NAME}-cidata.iso
genisoimage -output ${SF1_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
chmod 666 ${SF1_NAME}-cidata.iso

virsh change-media ${SF1_NAME} hdb --eject --config --force
virsh change-media ${SF1_NAME} hdb ${PWD}/${SF1_NAME}-cidata.iso --insert --config --force

#************************************************
# Clone images for the rest of entities: SF2
#************************************************

virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${SF2_NAME} --file ${SF2_NAME}.img --mac=${SF2_MAC} 
if [ $? -ne 0 ]; then
  echo "Error cloning image. Aborting"
  exit -1
fi

sleep 3

sudo virt-sysprep -a ${SF2_NAME}.img --hostname ${SF2_NAME} --firstboot-command 'sudo ssh-keygen -A' 

cat >meta-data <<EOF
instance-id: ${SF2_NAME}
local-hostname: ${SF2_NAME}
EOF
rm -rf ${SF2_NAME}-cidata.iso
genisoimage -output ${SF2_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
chmod 666 ${SF2_NAME}-cidata.iso

virsh change-media ${SF2_NAME} hdb --eject --config --force
virsh change-media ${SF2_NAME} hdb ${PWD}/${SF2_NAME}-cidata.iso --insert --config --force

#************************************************
# Clone images for the rest of entities: SF2_PROXY
#************************************************

virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${SF2_PROXY_NAME} --file ${SF2_PROXY_NAME}.img --mac=${SF2_PROXY_MAC} 
if [ $? -ne 0 ]; then
  echo "Error cloning image. Aborting"
  exit -1
fi

sleep 3

sudo virt-sysprep -a ${SF2_PROXY_NAME}.img --hostname ${SF2_PROXY_NAME} --firstboot-command 'sudo ssh-keygen -A' 

cat >meta-data <<EOF
instance-id: ${SF2_PROXY_NAME}
local-hostname: ${SF2_PROXY_NAME}
EOF
rm -rf ${SF2_PROXY_NAME}-cidata.iso
genisoimage -output ${SF2_PROXY_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
chmod 666 ${SF2_PROXY_NAME}-cidata.iso

virsh change-media ${SF2_PROXY_NAME} hdb --eject --config --force
virsh change-media ${SF2_PROXY_NAME} hdb ${PWD}/${SF2_PROXY_NAME}-cidata.iso --insert --config --force

#************************************************
# Start everything up
#************************************************

virsh start ${CLASSIFIER1_NAME}
virsh start ${SFF1_NAME}
virsh start ${SFF2_NAME}
virsh start ${SF1_NAME}
virsh start ${SF2_NAME}
virsh start ${CLASSIFIER2_NAME}
virsh start ${SF2_PROXY_NAME}


##Test

ssh-keygen -R ${CLASSIFIER1_IP}
ssh-keygen -R ${CLASSIFIER2_IP}
ssh-keygen -R ${SFF1_IP}
ssh-keygen -R ${SFF2_IP}
ssh-keygen -R ${SF1_IP}
ssh-keygen -R ${SF2_IP}
ssh-keygen -R ${SF2_PROXY_IP}


sleep 160

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.10 "echo hola"
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.20 "echo hola"
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.30 "echo hola"
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.40 "echo hola"
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.50 "echo hola"
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.60 "echo hola"
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.70 "echo hola"
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi


ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo /vagrant/ovs/setup_classifier_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF1_IP} "sudo /vagrant/ovs/setup_sff_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF1_IP} "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_IP} "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF2_IP} "sudo /vagrant/ovs/setup_sff_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER2_IP} "sudo /vagrant/ovs/setup_classifier_ovs.sh"

./ovs/setup_sfc_proxy.py
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo nohup /vagrant/ovs/setup_sf_proxy.sh & sleep 1"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app ping -c 5 192.168.2.2"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER2_IP} "sudo ip netns exec app python -m SimpleHTTPServer 80 &" 
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app wget http://192.168.2.2/"




exit 0






















































UBUNTU_IMAGE_URL=https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
UBUNTU_IMAGE_NAME=$(basename ${UBUNTU_IMAGE_URL})
if [ ! -e ${UBUNTU_IMAGE_NAME} ]; then 
   wget ${UBUNTU_IMAGE_URL}
fi
CLASSIFIER1_IP=192.168.122.10

#sudo virt-sysprep  --root-password password:m -a ubuntu-14.04-server-cloudimg-amd64-disk1.img 
vagrant destroy -f

vagrant up classifier1
vagrant halt classifier1

virt-clone --connect qemu:///system --original $(virsh list --all|tr -s ' ' '\n'|grep classifier1) --name classifier2 --file classifier2

#vagrant up classifier1
virsh start $(virsh list --all|tr -s ' ' '\n'|grep classifier1)

sudo chmod 664 classifier2


cat >initScript.sh <<EOF
#/bin/bash
ssh-keygen -A
#sudo ip a d 192.168.60.10/24 dev eth1
#sudo ip a a 192.168.60.20/24 dev eth1
EOF

sudo virt-sysprep -d classifier1.raw --firstboot ./initScript.sh

sudo virt-sysprep -d classifier1.raw --run-command "sudo sed -i 's/192.168.60.10/192.168.60.20/' /etc/network/interfaces"

virsh start classifier2





echo "#cloud-config\npassword: fedora\nchpasswd: {expire: False}\nssh_pwauth: True" > user-data
NAME="classifier1"
echo "instance-id: $NAME; local-hostname: $NAME" > meta-data

#virsh net-update nsh modify ip "<ip address='192.168.60.1' netmask='255.255.255.0'></ip>" --live --config






virt-install --name ${CLASSIFIER1_NAME} \
  --memory 2048 \
  --disk path=classifier1.img  \
  --import \
  --network network=default,mac=${CLASSIFIER1_MAC},model=virtio

  --extra-args="ip=${CLASSIFIER1_IP}::192.168.60.1:255.255.255.0:${CLASSIFIER1_NAME}:eth0:none"

virt-install --name ${CLASSIFIER2_NAME} \
  --memory 2048 \
  --disk path=/var/lib/libvirt/images/template.img  \
  --import \
  --network network=default,mac=${CLASSIFIER2_MAC},model=virtio 
  --extra-args="ip=${CLASSIFIER1_IP}::192.168.60.1:255.255.255.0:${CLASSIFIER1_NAME}:eth0:none"


cp ${UBUNTU_VBOX_NAME}.box ${UBUNTU_VBOX_NAME}

vagrant box remove -f ${UBUNTU_VBOX_NAME}
vagrant mutate ${UBUNTU_VBOX_NAME} libvirt
rm ${UBUNTU_VBOX_NAME}

#VBoxManage setextradata global VBoxInternal/CPUM/SSE4.1 1
#VBoxManage setextradata global VBoxInternal/CPUM/SSE4.2 1

### Halt current VMS in order to clean up dirty environment

vagrant halt -f

