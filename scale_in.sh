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

#************************************************
# Configure OpenDayLight
#************************************************

#************************************************
# Configure OpenDayLight
#************************************************

curl -X DELETE \
  http://localhost:8181/restconf/config/service-node:service-nodes/service-node/sf${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4='


curl -X DELETE \
  http://localhost:8181/restconf/config/service-function:service-functions/service-function/firewall-${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4='

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-forwarder:service-function-forwarders/service-function-forwarder:service-function-forwarder/SFF2/service-function-dictionary/firewall-${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4='


curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-chain:service-function-chains/service-function-chain/SFC${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4='

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-path:service-function-paths/service-function-path/SFP${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4='

curl -X DELETE \
  http://localhost:8181/restconf/config/ietf-access-control-list:access-lists/acl/ietf-access-control-list:ipv4-acl/ACL${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \

curl -X DELETE \
  http://localhost:8181/restconf/config/ietf-access-control-list:access-lists/acl/ietf-access-control-list:ipv4-acl/ACL${VM_ID}-Reverse \
  -H 'authorization: Basic YWRtaW46YWRtaW4='


curl -X POST \
  http://localhost:8181/restconf/operations/rendered-service-path:delete-rendered-path \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: 3f80c118-b0c5-7f33-dd17-5e65d651ba1b' \
  -d '{
	"input": {
        "name": "RSP'${VM_ID}'"
    }
}'

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-classifier:service-function-classifiers/service-function-classifier/ServiceFunctionClassifier${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4='

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-classifier:service-function-classifiers/service-function-classifier/ServiceFunctionClassifier${VM_ID}-Reverse \
  -H 'authorization: Basic YWRtaW46YWRtaW4='

#************************************************
# Configure Classifiers
#************************************************
cat > classifier1.sh << EOF
ip netns del app${VM_ID}
ovs-vsctl del-port br-sfc veth-br${VM_ID}
EOF

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} 'sudo bash -s -x ' < classifier1.sh

#TODO: Remove the proper ip below. It is not strictly needed as everything goes back via veth-app, but it would be a good practice
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER2_IP} "sudo ip netns exec app arp -d 192.168.2.210 -i veth-app"

rm classifier1.sh



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

