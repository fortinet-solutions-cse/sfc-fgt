#!/bin/bash

VM_ID=$1

source env.sh

if [ -z ${VM_ID} ]; then
  echo "Next VM to scale up needs an Id."
  exit -1
fi


export VM_PROXY_ID=$((${VM_ID}+1))

if [ ${VM_ID} -lt 90 ]; then
   echo "Error: Id should be greater than 90 to avoid collision with previous IPs"
   exit -1
fi


#VARS

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


#Networks

virsh net-destroy virbr${VM_ID}
virsh net-destroy virbr${VM_PROXY_ID}

virsh destroy ${SF_NAME}
virsh destroy ${SF_PROXY_NAME}

virsh undefine ${SF_NAME}
virsh undefine ${SF_PROXY_NAME}

virsh net-update default delete ip-dhcp-host \
          "<host mac='${SF_MAC_ADMIN}' name='${SF_NAME}' ip='${SF_IP_ADMIN}' />" \
           --live

virsh net-update virbr1 delete ip-dhcp-host \
          "<host mac='${SF_PROXY_MAC}' name='${SF_PROXY_NAME}' ip='${SF_PROXY_IP}' />" \
           --live


rm -f ${SF_PROXY_NAME}.img
rm -f ${SF_PROXY_NAME}-cidata.iso

rm -f fortios${VM_ID}.qcow2
rm -rf cfg-drv-fgt${VM_ID}
rm -rf ${SF_NAME}-cidata.iso
rm -f fgt-logs${VM_ID}.qcow2

rm -f virbr${VM_ID}
rm -f virbr${VM_PROXY_ID}

