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
   if [ $? -ne 0 ] ; then
      echo "Failed to resize ubuntu base image. Exiting..."
      exit -1
   fi
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
      <host mac='${SF2_MAC_ADMIN}' ip='${SF2_IP_ADMIN}'/>
      <host mac='${SF2_PROXY_MAC}' name='${SF2_PROXY_NAME}' ip='${SF2_PROXY_IP}'/>
    </dhcp>
  </ip>
</network>
EOF

cat >virbr2 <<EOF
<network>
  <name>virbr2</name>
  <bridge name='virbr2' stp='off' delay='0' />
  <mac address='52:54:00:79:7c:c4'/>
  <host mac='${SF2_MAC}' ip='${SF2_IP}'/>
  <host mac='${SF2_PROXY_MAC2}' ip='${SF2_PROXY_IP2}'/>
</network>
EOF

#   <dhcp>
#      <range start='192.168.70.2' end='192.168.70.254'/>
#   </dhcp>

#      <host mac='${SF2_MAC}' ip='${SF2_IP}'/>
#      <host mac='${SF2_PROXY_MAC2}' ip='${SF2_PROXY_IP2}'/>

cat >virbr3 <<EOF
<network>
  <name>virbr3</name>
  <bridge name='virbr3' stp='off' delay='0' />
  <mac address='52:54:00:79:7c:c5'/>
  <host mac='${SF2_MAC2}' ip='${SF2_IP2}'/>
  <host mac='${SF2_PROXY_MAC3}' ip='${SF2_PROXY_IP3}'/>
</network>
EOF

#    <dhcp>
#      <range start='192.168.80.2' end='192.168.80.254'/>
#    </dhcp>
#      <host mac='${SF2_MAC2}' ip='${SF2_IP2}'/>
#      <host mac='${SF2_PROXY_MAC3}' ip='${SF2_PROXY_IP3}'/>


sudo virsh net-create virbr1
sudo virsh net-create virbr2
sudo virsh net-create virbr3

sudo brctl setageing virbr2 0
sudo brctl setageing virbr3 0

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
# Stop classifier1 vm for cloning to the rest
#************************************************
sleep 30

virsh destroy ${CLASSIFIER1_NAME}

sleep 30


#************************************************
# Clone images for the rest of vms
#************************************************
declare -A VM_MAC=( [${CLASSIFIER2_NAME}]=${CLASSIFIER2_MAC} \
   [${SFF1_NAME}]=${SFF1_MAC} \
   [${SFF2_NAME}]=${SFF2_MAC} \
   [${SF1_NAME}]=${SF1_MAC} \
#   [${SF2_NAME}]=${SF2_MAC} \
   [${SF2_PROXY_NAME}]=${SF2_PROXY_MAC})

for VM_NAME in ${!VM_MAC[@]}; do

  echo "Cloning $VM_NAME with MAC: ${VM_MAC[${VM_NAME}]}"

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

done


#************************************************
# Start everything up
#************************************************

virsh start ${CLASSIFIER1_NAME}
virsh start ${SFF1_NAME}
virsh start ${SFF2_NAME}
virsh start ${SF1_NAME}
#virsh start ${SF2_NAME}
virsh start ${CLASSIFIER2_NAME}
virsh start ${SF2_PROXY_NAME}

#************************************************
# Start FGT-VM
#************************************************

virsh destroy sf2
virsh undefine sf2
rm -f fortios.qcow2
rm -rf cfg-drv-fgt
rm -rf ${SF2_NAME}-cidata.iso

#TODO: Remove this or replace with your original image location
cp ../Downloads/fortios.qcow2 .

mkdir -p cfg-drv-fgt/openstack/latest/
mkdir -p cfg-drv-fgt/openstack/content/

cat >cfg-drv-fgt/openstack/content/0000 <<EOF
-----BEGIN FGT VM LICENSE-----

<empty....fill your own!>

-----END FGT VM LICENSE-----
EOF

cat >cfg-drv-fgt/openstack/latest/user_data <<EOF
config system interface
edit "port1"
set ip 192.168.122.40/24
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
        set logtraffic disable
    next
end

EOF

#        set uuid 668d9c5e-54c9-51e7-6cb5-4b9cb2896179

sudo mkisofs -publisher "OpenStack Nova 12.0.2" -J -R -V config-2 -o ${SF2_NAME}-cidata.iso cfg-drv-fgt

virt-install --connect qemu:///system --noautoconsole --filesystem ${PWD},shared_dir --import --name ${SF2_NAME} --ram 1024 --vcpus 1 --disk fortios.qcow2,size=3 --disk fgt-logs.qcow2,size=30 --disk ${SF2_NAME}-cidata.iso,device=cdrom,bus=ide,format=raw,cache=none --network bridge=virbr0,mac=${SF2_MAC_ADMIN},model=virtio --network network=virbr2,mac=${SF2_MAC},model=virtio --network network=virbr3,mac=${SF2_MAC2},model=virtio


sleep 45

#************************************************
# Add two more interfaces to SF2_PROXY
#************************************************

virsh attach-interface --domain ${SF2_PROXY_NAME} --type network \
        --source virbr2 \
        --mac ${SF2_PROXY_MAC2} --config --live

virsh attach-interface --domain ${SF2_PROXY_NAME} --type network \
        --source virbr3 \
        --mac ${SF2_PROXY_MAC3} --config --live


#************************************************
# Quick test on ovs
#************************************************

ssh-keygen -R ${CLASSIFIER1_IP}
ssh-keygen -R ${CLASSIFIER2_IP}
ssh-keygen -R ${SFF1_IP}
ssh-keygen -R ${SFF2_IP}
ssh-keygen -R ${SF1_IP}
ssh-keygen -R ${SF2_IP}
ssh-keygen -R ${SF2_PROXY_IP}

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

#ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_IP} ${COMMAND}
#if [ $? -ne 0 ]; then
#  echo "Error testing. Aborting"
#  exit -1
#fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} ${COMMAND}
if [ $? -ne 0 ]; then
  echo "Error testing. Aborting"
  exit -1
fi


ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo /vagrant/ovs/setup_classifier_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF1_IP} "sudo /vagrant/ovs/setup_sff_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF1_IP} "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1 2>&1 >sf1_log.txt" &

#ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_IP} "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1" &

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SFF2_IP} "sudo /vagrant/ovs/setup_sff_ovs.sh"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER2_IP} "sudo /vagrant/ovs/setup_classifier_ovs.sh" &

./ovs/setup_sfc_proxy.py
 
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo ifconfig eth1 up; \
                                                                                 sudo ifconfig eth2 up;"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo apt-get install -y python3-pip;sudo pip3 install hexdump"

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo pkill proxy; sudo /vagrant/proxy.py --encap_if eth0 --unencap_in_if eth2 --unencap_out_if eth1 2>&1 >proxy.log" &

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app ping -c 5 192.168.2.2"
 
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app wget -t1 http://192.168.2.2/"

exit 0


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

cp ../PycharmProjects/nsh-proxy/proxy.py .;rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -r -v --max-size=1048576 ./*  ${SF2_PROXY_IP}:/vagrant/


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
diag debug flow filter add 192.168.2.2
#diag debug flow show console enable
diag debug flow trace start 100
diag debug enable


diag debug application httpsd -1 (FYI)


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
