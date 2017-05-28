#!/bin/bash
set -x 


# This needs libguestfs-tools
# Exec: 
sudo apt-get install openjdk-8-jdk
# sudo chmod a+r -R /var/lib/libvirt/images/
# sudo chmod a+r -R /boot/*
sudo apt-get install libguestfs-tools qemu-kvm libvirt-bin virtinst bridge-utils cpu-checker virt-manager

#activate source code repos before running next command
# sudo apt-get build-dep vagrant ruby-libvirt
# sudo apt-get install qemu libvirt-bin ebtables dnsmasq
# sudo apt-get install libxslt-dev libxml2-dev libvirt-dev zlib1g-dev ruby-dev

# vagrant plugin install vagrant-libvirt
# if failure then try this (ubuntu 16.04 with vagrant 1.8.1):
# sudo sed -i'' "s/Specification.all = nil/Specification.reset/" /usr/lib/ruby/vendor_ruby/vagrant/bundler.rb
#vagrant plugin install vagrant-libvirt

root_dir=$(dirname $0)

nshproxy=true

if [ "${root_dir}" != "." ] ; then
    echo "Please run ./run_demo.sh $@"
    exit -1
fi

demo="./ovs/run_demo_ovs.sh"
features="odl-sfc-ui"
uninstall_features=""

demo="./ovs/run_demo_ovs.sh"
features="${features} odl-sfc-scf-openflow odl-sfc-openflow-renderer"
uninstall_features="odl-sfc-vpp-renderer"

#Install sshpass
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

#Check if SFC is started
karaf=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} system:name)
if [ $? -ne 0 ] ;  then
    echo "Please start ODL SFC first."
    exit -1
fi

echo "Install and wait for sfc features: ${features}"
#Uninstall unnecessary features automatically
sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} feature:uninstall ${uninstall_features}

#Install necessary features automatically
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

# For OVS and OVS_DPDK use case, must make sure renderer and classifier are intialized successfully
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

./cleanup_demo.sh

HTTPPROXY="${http_proxy}"
HTTPSPROXY="${https_proxy}"

if [ "${HTTP_PROXY}" != "" ] ; then
    HTTPPROXY=${HTTP_PROXY}
fi
if [ "${HTTPS_PROXY}" != "" ] ; then
    HTTPSPROXY=${HTTPS_PROXY}
fi
if [ "${HTTPPROXY}" == "" ] ; then
    HTTPPROXY=${HTTPSPROXY}
fi
if [ "${HTTPSPROXY}" == "" ] ; then
    HTTPSPROXY=${HTTPPROXY}
fi

#if [ ! -e ./${UBUNTU_VBOX_NAME}.box ] ; then
#    wget ${UBUNTU_VBOX_URL}
#fi


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


# This works !!!

NAME="classifier1"
source env.sh

UBUNTU_IMAGE_URL=https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
UBUNTU_IMAGE_NAME=$(basename ${UBUNTU_IMAGE_URL})
if [ ! -e ${UBUNTU_IMAGE_NAME} ]; then 
   wget ${UBUNTU_IMAGE_URL}
fi

virsh destroy classifier1
virsh undefine classifier1

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
    </dhcp>
  </ip>
</network>
EOF
sudo virsh net-create virbr1

if [ ! -f ${HOME}/.ssh/id_rsa.pub ]; then 
  echo "Need ${HOME}/.ssh/id_rsa.pub generated. Do ssh-keygen"
  exit -1
fi
cat >meta-data <<EOF
instance-id: ${CLASSIFIER1_IP};
local-hostname: ${CLASSIFIER1_IP}
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


sudo cp ubuntu-14.04-server-cloudimg-amd64-disk1.img classifier1.img
sudo virt-sysprep -a $NAME.img --root-password password:m 
sudo virt-sysprep -a $NAME.img --firstboot-command 'useradd -m -p "" vagrant ; chage -d 0 vagrant'
rm -rf $NAME-cidata.iso
genisoimage -output $NAME-cidata.iso -volid cidata -joliet -rock user-data meta-data
virt-install --import --name $NAME --ram 2048 --vcpus 1 --disk $NAME.img --disk $NAME-cidata.iso,device=cdrom --network bridge=virbr1,mac=${CLASSIFIER1_MAC}

ssh ${CLASSIFIER1_IP} "sudo mkdir /vagrant/"
ssh ${CLASSIFIER1_IP} "sudo chmod 777 /vagrant/"


rsync -r -v --max-size=1048576 ./*  ${CLASSIFIER1_IP}:/vagrant/

ssh ${CLASSIFIER1_IP} "sudo /vagrant/ovs/install_ovs.sh"

# This works!! ##






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

### Just install one VM once but cloned for all the rest VMs ###
vagrant up ${CLASSIFIER1_NAME} --provider libvirt
vagrant ssh ${CLASSIFIER1_NAME} -c "if [ -x /usr/lib/openvswitch-switch-dpdk/ovs-vswitchd -a -x /home/vagrant/ovs/vswitchd/ovs-vswitchd ] ; then exit 0; else exit -1; fi"
if [ $? -ne 0 ] ; then
    vagrant ssh ${CLASSIFIER1_NAME} -c "sudo /vagrant/ovs/install_ovs.sh ${HTTPPROXY} ${HTTPSPROXY}"
    if [ $? -ne 0 ] ; then
        echo "Failed to install ovs on ${CLASSIFIER1_NAME}"
        exit -1
    fi
    vagrant ssh ${CLASSIFIER1_NAME} -c "if [ -x /usr/lib/openvswitch-switch-dpdk/ovs-vswitchd -a -x /home/vagrant/ovs/vswitchd/ovs-vswitchd ] ; then exit 0; else exit -1; fi"
    if [ $? -eq 0 ] ; then

        vagrant package --output ./${UBUNTU_VBOX_NAME}.updated ${CLASSIFIER1_NAME}
        vagrant halt -f
        vagrant destroy -f
        vagrant box remove -f ${UBUNTU_VBOX_NAME}
        mv -f ./${UBUNTU_VBOX_NAME}.updated ./${UBUNTU_VBOX_NAME}
        vagrant box add  --name ${UBUNTU_VBOX_NAME} ${UBUNTU_VBOX_NAME}
        rm -rf ./.vagrant

#        vagrant package --output ./${UBUNTU_VBOX_IMAGE}.ready ${CLASSIFIER1_NAME}
#        vagrant halt -f
#        vagrant destroy -f
#        vagrant box remove -f ${UBUNTU_VBOX_NAME}
#        vagrant box add ${UBUNTU_VBOX_NAME}
#        rm -rf ./.vagrant
#        mv -f ./${UBUNTU_VBOX_IMAGE}.ready ./${UBUNTU_VBOX_IMAGE}
    else
       echo "OVS does not seem to be installed correctly. Aborting"
       exit -1
    fi
       
fi

# Start using virt-install instead of Vagrant

vagrant up  --provider libvirt

vagrant ssh ${CLASSIFIER1_NAME} -c "sudo /vagrant/ovs/setup_classifier_ovs.sh"

vagrant ssh ${SFF1_NAME} -c "sudo /vagrant/ovs/setup_sff_ovs.sh"

vagrant ssh ${SF1_NAME} -c "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1"

vagrant ssh ${SF2_NAME} -c "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1"

vagrant ssh ${SFF2_NAME} -c "sudo /vagrant/ovs/setup_sff_ovs.sh"

vagrant ssh ${CLASSIFIER2_NAME} -c "sudo /vagrant/ovs/setup_classifier_ovs.sh"

if [ $nshproxy = true ] ; then
        ./ovs/setup_sfc_proxy.py
        vagrant ssh ${SF2_PROXY_NAME} -c "sudo nohup /vagrant/ovs/setup_sf_proxy.sh & sleep 1"
else
        ./ovs/setup_sfc.py
fi

vagrant ssh ${CLASSIFIER1_NAME} -c "sudo ip netns exec app ping -c 5 192.168.2.2"
vagrant ssh ${CLASSIFIER2_NAME} -c "sudo ip netns exec app python -m SimpleHTTPServer 80 &" 
vagrant ssh ${CLASSIFIER1_NAME} -c "sudo ip netns exec app wget http://192.168.2.2/"

