#!/bin/bash

set -x
source env.sh

sudo echo "Please input sudo password for later commands:"

#************************************************
#Install sshpass
#************************************************
toolscheck=$(exec 2>/dev/null;which sshpass && which wget && which curl && which ssh)
if [ $? -ne 0 ] ; then
    yum=$(which yum 2>/dev/null)
    if [ $? -eq 0 ] ; then
        sudo yum install -y sshpass wget curl openssh-clients
    fi

    aptget=$(which apt-get 2>/dev/null)
    if [ $? -eq 0 ] ; then
        sudo apt-get install -y sshpass wget curl openssh-client
    fi
fi

source ./env.sh

#************************************************
#Check if SFC is started
#************************************************
karaf=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} system:name)
if [ $? -ne 0 ] ;  then
    echo "Please start ODL SFC first."
    exit -1
fi

echo "Install and wait for sfc features: ${features}"

#************************************************
#Uninstall unnecessary features automatically
#************************************************
sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} feature:uninstall ${uninstall_features}

#************************************************
#Install necessary features automatically
#************************************************
sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} feature:install odl-restconf ${features}
retries=6
while [ $retries -gt 0 ]
do
    installed=0
    installed_features=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} feature:list -i | grep sfc | awk '{print $1;}')
    echo "Installed features: ${installed_features}"
    echo "Expected features: ${features}"
    i=0
    j=0
    for feature in ${features}
    do
        i=$((i+1))
        if [[ ${installed_features} =~ $feature ]] ; then
            j=$((j+1))
        fi
    done
    if [ $i -eq $j ] ; then
        installed=1
        break
    fi
    echo "Waiting for ${features} installed..."
    sleep 10
    retries=$((retries-1))
done

if [ $installed -ne 1 ] ; then
    echo "Failed to install features: ${features}"
    exit -1
fi

#************************************************
# For OVS and OVS_DPDK use case, must make sure renderer and classifier are intialized successfully
#************************************************
retries=10
while [ $retries -gt 0 ]
do
    OK=0
    result=$(curl -H "Content-Type: application/json" -H "Cache-Control: no-cache" -X GET --user admin:admin http://${LOCALHOST}:8181/restconf/operational/network-topology:network-topology/)
    OK=$((OK+$?))
    result=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} display | grep "successfully started the SfcOfRenderer")
    OK=$((OK+$?))
    result=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} display | grep "successfully started the SfcScfOfRenderer")
    OK=$((OK+$?))
    if [ $OK -eq 0 ] ; then
        break
    fi
    echo "Waiting Openflow renderer and classifier initialized..."
    sleep 3
    retries=$((retries-1))
done

if [ $retries -eq 0 ] ; then
    echo "features are not started correctly: ${features}"
    exit -1
fi

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
   qemu-img resize ${UBUNTU_IMAGE_NAME} +1Gb
fi


#************************************************
# Clean previous installations in virsh
#************************************************

./cleanup_demo.sh

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
# Stop base vm for cloning
#************************************************
sleep 60

virsh destroy ${CLASSIFIER1_NAME}

sleep 60

#TODO: Next Commands should be placed in a loop to iterate through every VM
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

COMMAND="sudo ovs-vsctl show"

#TODO: Use a loop for next commands

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER2_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF1_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF2_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF1_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi


ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo /vagrant/ovs/setup_classifier_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF1_IP} "sudo /vagrant/ovs/setup_sff_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF1_IP} "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1" &

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_IP} "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1" &

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF2_IP} "sudo /vagrant/ovs/setup_sff_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER2_IP} "sudo /vagrant/ovs/setup_classifier_ovs.sh" &

./ovs/setup_sfc_proxy.py
 
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo nohup /vagrant/ovs/setup_sf_proxy.sh & sleep 1" &

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app ping -c 5 192.168.2.2"
 
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app wget -T1 http://192.168.2.2/"

exit 0


