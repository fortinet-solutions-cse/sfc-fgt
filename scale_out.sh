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
# Use: ./scale_out.sh <id_of_new_vm> <fortios qcow image location> <network cidr for sfc>
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
# Check Network CIDR for Service Chain
#************************************************
if [ -z "$3" ]; then
  echo "Need Network CIDR for Service Chain"
  exit -1
fi

NETWORK_CIDR=$3
NETWORK_CIDR_IP=${NETWORK_CIDR%%/*}


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


#************************************************
# Configure Classifiers
#************************************************

cat > classifier1.sh << EOF
ip netns add app${VM_ID}
ip link add veth-app${VM_ID} type veth peer name veth-br${VM_ID}
ovs-vsctl add-port br-sfc veth-br${VM_ID}
ip link set dev veth-br${VM_ID} up
ip link set veth-app${VM_ID} netns app${VM_ID}

ip netns exec app${VM_ID} ifconfig veth-app${VM_ID} ${NETWORK_CIDR_IP}/24 up
ip netns exec app${VM_ID} ip link set dev veth-app92 addr 00:00:11:11:11:${VM_ID}
ip netns exec app${VM_ID} arp -s 192.168.2.2 00:00:22:22:22:22 -i veth-app${VM_ID}
ip netns exec app${VM_ID} ip link set dev veth-app${VM_ID} up
ip netns exec app${VM_ID} ip link set dev lo up
ip netns exec app${VM_ID} ifconfig veth-app${VM_ID} mtu 1400
ip netns exec app${VM_ID} ethtool -K veth-app${VM_ID} tx off
EOF
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} 'sudo bash -s -x ' < classifier1.sh

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER2_IP} "sudo ip netns exec app arp -s ${NETWORK_CIDR_IP} 00:00:11:11:11:${VM_ID} -i veth-app"

rm classifier1.sh

#************************************************
# Configure OpenDayLight
#************************************************

curl -X PUT \
  http://localhost:8181/restconf/config/service-node:service-nodes/service-node/sf${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: fba62f4b-0dd7-867b-2597-d92f2ac7ca2f' \
  -d '{
    "service-node": [
        {
            "name": "sf'${VM_ID}'",
            "ip-mgmt-address": "192.168.70.'${VM_ID}'",
            "service-function": [
                "firewall-'${VM_ID}'"
            ]
        }
    ]
}'


curl -X PUT \
  http://localhost:8181/restconf/config/service-function:service-functions/service-function/firewall-${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: c22e64dc-24d7-d2be-1333-1430cabec171' \
  -d '{
    "service-function": [
        {
            "name": "firewall-'${VM_ID}'",
            "ip-mgmt-address": "192.168.70.'${VM_ID}'",
            "type": "firewall'${VM_ID}'",
            "sf-data-plane-locator": [
                {
                    "name": "firewall-'${VM_ID}'-dpl",
                    "port": 4789,
                    "ip": "192.168.70.'${VM_ID}'",
                    "service-function-proxy:proxy-data-plane-locator": {
                        "ip": "192.168.60.'${VM_PROXY_ID}'",
                        "port": 4790,
                        "transport": "service-locator:vxlan-gpe"
                    },
                    "service-function-forwarder": "SFF2",
                    "transport": "service-locator:vxlan"
                }
            ]
        }
    ]
}'

curl -X PUT \
  http://localhost:8181/restconf/config/service-function-forwarder:service-function-forwarders/service-function-forwarder:service-function-forwarder/SFF2/service-function-dictionary/firewall-${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: f9f90229-7e5a-5bd1-9ffa-33b041fe4f64' \
  -d '{
    "service-function-dictionary": [
        {
            "name": "firewall-'${VM_ID}'",
            "sff-sf-data-plane-locator": {
                "sff-dpl-name": "sff2-dpl",
                "sf-dpl-name": "firewall-'${VM_ID}'-dpl"
            }
        }
    ]
}'

curl -X PUT \
  http://localhost:8181/restconf/config/service-function-chain:service-function-chains/service-function-chain/SFC${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: 893c0087-8de7-ad63-60b9-6c412124c72c' \
  -d '{
    "service-function-chain": [
        {
            "name": "SFC'${VM_ID}'",
            "sfc-service-function": [
                {
                    "name": "dpi-abstract1",
                    "type": "dpi"
                },
                {
                    "name": "firewall-abstract'${VM_ID}'",
                    "type": "firewall'${VM_ID}'"
                }
            ]
        }
    ]
}'

curl -X PUT \
  http://localhost:8181/restconf/config/service-function-path:service-function-paths/service-function-path/SFP${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: b6a883b6-0641-cdcc-11c2-01c5d9d1a39b' \
  -d '{
    "service-function-path": [
        {
            "name": "SFP'${VM_ID}'",
            "starting-index": 255,
            "symmetric": true,
            "service-chain-name": "SFC'${VM_ID}'",
            "context-metadata": "NSH1"
        }
    ]
}'

curl -X PUT \
  http://localhost:8181/restconf/config/ietf-access-control-list:access-lists/acl/ietf-access-control-list:ipv4-acl/ACL${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: a2905d6e-30f4-8832-2076-6fc8a49e6eb9' \
  -d '{
    "acl": [
        {
            "acl-type": "ietf-access-control-list:ipv4-acl",
            "acl-name": "ACL'${VM_ID}'",
            "access-list-entries": {
                "ace": [
                    {
                        "rule-name": "ACE'${VM_ID}'-1",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 0
                            },
                            "destination-port-range": {
                                "lower-port": 0
                            },
                            "source-ipv4-network": "'${NETWORK_CIDR}'",
                            "destination-ipv4-network": "192.168.2.0/24",
                            "protocol": 1
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP'${VM_ID}'"
                        }
                    },
                    {
                        "rule-name": "ACE'${VM_ID}'-2",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 0
                            },
                            "destination-port-range": {
                                "lower-port": 80
                            },
                            "source-ipv4-network": "'${NETWORK_CIDR}'",
                            "destination-ipv4-network": "192.168.2.0/24",
                            "protocol": 6
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP'${VM_ID}'"
                        }
                    }
                ]
            }
        }
    ]
}'


curl -X PUT \
  http://localhost:8181/restconf/config/ietf-access-control-list:access-lists/acl/ietf-access-control-list:ipv4-acl/ACL${VM_ID}-Reverse \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: b86749db-3744-6681-5d92-3b3333e3065c' \
  -d '{
    "acl": [
        {
            "acl-type": "ietf-access-control-list:ipv4-acl",
            "acl-name": "ACL'${VM_ID}'-Reverse",
            "access-list-entries": {
                "ace": [
                    {
                        "rule-name": "ACE'${VM_ID}'-1-Reverse",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 0
                            },
                            "destination-port-range": {
                                "lower-port": 0
                            },
                            "source-ipv4-network": "192.168.2.0/24",
                            "destination-ipv4-network": "'${NETWORK_CIDR}'",
                            "protocol": 1
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP'${VM_ID}'-Reverse"
                        }
                    },
                    {
                        "rule-name": "ACE'${VM_ID}'-2-Reverse",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 80
                            },
                            "destination-port-range": {
                                "lower-port": 0
                            },
                            "source-ipv4-network": "192.168.2.0/24",
                            "destination-ipv4-network": "'${NETWORK_CIDR}'",
                            "protocol": 6
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP'${VM_ID}'-Reverse"
                        }
                    }
                ]
            }
        }
    ]
}'


curl -X POST \
  http://localhost:8181/restconf/operations/rendered-service-path:create-rendered-path \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: 3f80c118-b0c5-7f33-dd17-5e65d651ba1b' \
  -d '{
	"input": {
        "name": "RSP'${VM_ID}'",
        "parent-service-function-path": "SFP'${VM_ID}'"
    }
}'

curl -X PUT \
  http://localhost:8181/restconf/config/service-function-classifier:service-function-classifiers/service-function-classifier/ServiceFunctionClassifier${VM_ID} \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: b66876d1-7e6b-5b2c-57f6-82f64a8423b3' \
  -d '
{
  "service-function-classifier": [
    {
      "name": "ServiceFunctionClassifier'${VM_ID}'",
      "acl": {
        "type": "ietf-access-control-list:ipv4-acl",
        "name": "ACL'${VM_ID}'"
      },
      "scl-service-function-forwarder": [
        {
          "name": "Classifier1",
          "interface": "veth-br'${VM_ID}'"
        }
      ]
    }
  ]
}'


curl -X PUT \
  http://localhost:8181/restconf/config/service-function-classifier:service-function-classifiers/service-function-classifier/ServiceFunctionClassifier${VM_ID}-Reverse \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: e023f9b4-2b85-6aa8-6b35-5b29397ffaa1' \
  -d '{
  "service-function-classifier": [
    {
      "name": "ServiceFunctionClassifier'${VM_ID}'-Reverse",
      "acl": {
        "type": "ietf-access-control-list:ipv4-acl",
        "name": "ACL'${VM_ID}'-Reverse"
      },
      "scl-service-function-forwarder": [
        {
          "name": "Classifier2",
          "interface": "veth-br"
        }
      ]
    }
  ]
}'