
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

