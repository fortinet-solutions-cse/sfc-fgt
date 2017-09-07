#!/bin/bash

#************************************************
# Scale out script for SFC demo
#   _____           _       ____        _
#  / ____|         | |     / __ \      | |
# | (___   ___ __ _| | ___| |  | |_   _| |_
#  \___ \ / __/ _` | |/ _ \ |  | | | | | __|
#  ____) | (_| (_| | |  __/ |__| | |_| | |_
# |_____/ \___\__,_|_|\___|\____/ \__,_|\__|
#
# Use: ./scale_out.sh <id_of_new_vm>
#
# Note id should be between 90 and 100
#
# Miguel Angel Muñoz Gonzalez
# magonzalez(at)fortinet.com
#
#************************************************

VM_ID=$1
source env.sh

#************************************************
# Check Arguments
#************************************************
if [ -z ${VM_ID} ]; then
  echo "Next VM to scale up needs an Id."
  exit -1
fi

export VM_PROXY_ID=$((${VM_ID}+1))

if [ ${VM_ID} -lt 90 ]; then
   echo "Error: Id should be greater than 90 to avoid collision with previous IPs"
   exit -1
fi

#************************************************
# Check Fortigate VM existence
#************************************************

if [ -z "$2" ]; then
  echo "Need location of Fortigate image"
  exit -1
fi
result=$(file $2)
if [[ $result == *"QEMU QCOW Image (v2)"* ]]; then
   echo "Supplied Fortigate image is in: $2"
   FORTIGATE_QCOW2=$2
else
   echo "Supplied Fortigate image does not look a qcow2 file"
   exit -1
fi
if [[ "$(realpath $FORTIGATE_QCOW2)" == "$(pwd)/fortios.qcow2" ]]; then
   echo "FortiGate image can not be named fortios.qcow2 in this directory. Choose different location/name"
   exit -1
fi

#************************************************
# Prepare variables
#************************************************

export SF_NAME=sf${VM_ID}
export SF_IP_ADMIN=192.168.122.${VM_ID}
export SF_IP=192.168.70.${VM_ID}
export SF_IP2=192.168.80.${VM_ID}
export SF_MAC_ADMIN=08:00:27:4c:22:${VM_ID}
export SF_MAC=08:00:27:4c:70:${VM_ID}
export SF_MAC2=08:00:27:4c:80:${VM_ID}

export SF_PROXY_NAME=sf${VM_ID}proxy
export SF_PROXY_IP=192.168.60.${VM_PROXY_ID}
export SF_PROXY_IP2=192.168.70.${VM_PROXY_ID}
export SF_PROXY_IP3=192.168.80.${VM_PROXY_ID}
export SF_PROXY_MAC=08:00:27:4c:60:${VM_PROXY_ID}
export SF_PROXY_MAC2=08:00:27:4c:70:${VM_PROXY_ID}
export SF_PROXY_MAC3=08:00:27:4c:80:${VM_PROXY_ID}


#************************************************
# Create new network and update existing
#************************************************

cat >virbr${VM_ID} <<EOF
<network>
  <name>virbr${VM_ID}</name>
  <bridge name='virbr${VM_ID}' stp='off' delay='0' />
  <mac address='52:54:00:79:7c:${VM_ID}'/>
  <host mac='${SF_MAC}' ip='${SF_IP}'/>
  <host mac='${SF_PROXY_MAC2}' ip='${SF_PROXY_IP2}'/>
</network>
EOF

cat >virbr${VM_PROXY_ID} <<EOF
<network>
  <name>virbr${VM_PROXY_ID}</name>
  <bridge name='virbr${VM_PROXY_ID}' stp='off' delay='0' />
  <mac address='52:54:00:79:7c:${VM_PROXY_ID}'/>
  <host mac='${SF_MAC2}' ip='${SF_IP2}'/>
  <host mac='${SF_PROXY_MAC3}' ip='${SF_PROXY_IP3}'/>
</network>
EOF

sudo virsh net-create virbr${VM_ID}
sudo virsh net-create virbr${VM_PROXY_ID}

virsh net-update default add ip-dhcp-host \
          "<host mac='${SF_MAC_ADMIN}' name='${SF_NAME}' ip='${SF_IP_ADMIN}' />" \
           --live

virsh net-update virbr1 add ip-dhcp-host \
          "<host mac='${SF_PROXY_MAC}' name='${SF_PROXY_NAME}' ip='${SF_PROXY_IP}' />" \
           --live

#************************************************
# Instantiate Proxy VM
#************************************************


echo "Cloning $SF_PROXY_NAME with MAC: ${SF_PROXY_MAC}"

cp ${PREVIOUS_SAVED_IMAGE_NAME} ${SF_PROXY_NAME}.img

sudo virt-sysprep -a ${SF_PROXY_NAME}.img --hostname ${SF_PROXY_NAME} --firstboot-command 'sudo ssh-keygen -A'

cat >meta-data <<EOF
instance-id: ${SF_PROXY_NAME}
local-hostname: ${SF_PROXY_NAME}
EOF

rm -rf ${SF_PROXY_NAME}-cidata.iso
genisoimage -output ${SF_PROXY_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
chmod 666 ${SF_PROXY_NAME}-cidata.iso

virt-install --connect qemu:///system --noautoconsole --filesystem ${PWD},shared_dir --import --name ${SF_PROXY_NAME} --ram 2048 --vcpus 1 --disk ${SF_PROXY_NAME}.img,size=3 --disk ${SF_PROXY_NAME}-cidata.iso,device=cdrom --network bridge=virbr1,mac=${SF_PROXY_MAC}

virsh change-media ${SF_PROXY_NAME} hdb --eject --config --force
virsh change-media ${SF_PROXY_NAME} hdb ${PWD}/${SF_PROXY_NAME}-cidata.iso --insert --config --force

#************************************************
# Instantiate FGT VM
#************************************************

rm -f fortios${VM_ID}.qcow2
rm -rf cfg-drv-fgt${VM_ID}
rm -rf ${SF_NAME}-cidata.iso

cp ${FORTIGATE_QCOW2} ./fortios${VM_ID}.qcow2

mkdir -p cfg-drv-fgt${VM_ID}/openstack/latest/
mkdir -p cfg-drv-fgt${VM_ID}/openstack/content/

cat >cfg-drv-fgt${VM_ID}/openstack/content/0000 <<EOF
-----BEGIN FGT VM LICENSE-----
<empty....fill your own!>
-----END FGT VM LICENSE-----
EOF

cat >cfg-drv-fgt${VM_ID}/openstack/latest/user_data <<EOF
config system interface
   edit "port1"
      set ip 192.168.122.${VM_ID}/24
   next
   edit "port2"
      set mtu-override enable
      set mtu 1400
   next
   edit "port3"
      set mtu-override enable
      set mtu 1400
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

sudo mkisofs -publisher "OpenStack Nova 12.0.2" -J -R -V config-2 -o ${SF_NAME}-cidata.iso cfg-drv-fgt${VM_ID}
virt-install --connect qemu:///system --noautoconsole --filesystem ${PWD},shared_dir --import --name ${SF_NAME} --ram 1024 --vcpus 1 --disk fortios${VM_ID}.qcow2,size=3 --disk fgt-logs${VM_ID}.qcow2,size=30 --disk ${SF_NAME}-cidata.iso,device=cdrom,bus=ide,format=raw,cache=none --network bridge=virbr0,mac=${SF_MAC_ADMIN},model=virtio --network bridge=virbr${VM_ID},mac=${SF_MAC},model=virtio --network bridge=virbr${VM_PROXY_ID},mac=${SF_MAC2},model=virtio

sleep 45

#************************************************
# Add two more interfaces to Proxy
#************************************************

virsh attach-interface --domain ${SF_PROXY_NAME} --type network \
        --source virbr${VM_ID} \
        --mac ${SF_PROXY_MAC2} --config --live

virsh attach-interface --domain ${SF_PROXY_NAME} --type network \
        --source virbr${VM_PROXY_ID} \
        --mac ${SF_PROXY_MAC3} --config --live

#************************************************
# Configure Proxy
#************************************************

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF_PROXY_IP} "sudo nohup bash /vagrant/ovs/setup_sfc_proxy.sh 2>&1 >sf${VM_ID}proxy.log" &
