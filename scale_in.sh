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
  http://localhost:8181/restconf/config/service-node:service-nodes/service-node/sf92 \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: fba62f4b-0dd7-867b-2597-d92f2ac7ca2f' \
  -d '{
    "service-node": [
        {
            "name": "sf92",
            "ip-mgmt-address": "192.168.70.92",
            "service-function": [
                "firewall-92"
            ]
        }
    ]
}'


curl -X DELETE \
  http://localhost:8181/restconf/config/service-function:service-functions/service-function/firewall-92 \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: c22e64dc-24d7-d2be-1333-1430cabec171' \
  -d '{
    "service-function": [
        {
            "name": "firewall-92",
            "ip-mgmt-address": "192.168.70.92",
            "type": "firewall92",
            "sf-data-plane-locator": [
                {
                    "name": "firewall-92-dpl",
                    "port": 4789,
                    "ip": "192.168.70.92",
                    "service-function-proxy:proxy-data-plane-locator": {
                        "ip": "192.168.60.93",
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

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-forwarder:service-function-forwarders/service-function-forwarder:service-function-forwarder/SFF2/service-function-dictionary/firewall-92 \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: f9f90229-7e5a-5bd1-9ffa-33b041fe4f64' \
  -d '{
    "service-function-dictionary": [
        {
            "name": "firewall-92",
            "sff-sf-data-plane-locator": {
                "sff-dpl-name": "sff2-dpl",
                "sf-dpl-name": "firewall-92-dpl"
            }
        }
    ]
}'

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-chain:service-function-chains/service-function-chain/SFC92 \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: 893c0087-8de7-ad63-60b9-6c412124c72c' \
  -d '{
    "service-function-chain": [
        {
            "name": "SFC92",
            "sfc-service-function": [
                {
                    "name": "dpi-abstract1",
                    "type": "dpi"
                },
                {
                    "name": "firewall-abstract92",
                    "type": "firewall92"
                }
            ]
        }
    ]
}'

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-path:service-function-paths/service-function-path/SFP92 \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: b6a883b6-0641-cdcc-11c2-01c5d9d1a39b' \
  -d '{
    "service-function-path": [
        {
            "name": "SFP92",
            "starting-index": 255,
            "symmetric": true,
            "service-chain-name": "SFC92",
            "context-metadata": "NSH1"
        }
    ]
}'

curl -X DELETE \
  http://localhost:8181/restconf/config/ietf-access-control-list:access-lists/acl/ietf-access-control-list:ipv4-acl/ACL92 \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: a2905d6e-30f4-8832-2076-6fc8a49e6eb9' \
  -d '{
    "acl": [
        {
            "acl-type": "ietf-access-control-list:ipv4-acl",
            "acl-name": "ACL92",
            "access-list-entries": {
                "ace": [
                    {
                        "rule-name": "ACE92-1",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 0
                            },
                            "destination-port-range": {
                                "lower-port": 0
                            },
                            "source-ipv4-network": "192.168.2.210/32",
                            "destination-ipv4-network": "192.168.2.0/24",
                            "protocol": 1
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP92"
                        }
                    },
                    {
                        "rule-name": "ACE92-2",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 0
                            },
                            "destination-port-range": {
                                "lower-port": 80
                            },
                            "source-ipv4-network": "192.168.2.210/32",
                            "destination-ipv4-network": "192.168.2.0/24",
                            "protocol": 6
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP92"
                        }
                    }
                ]
            }
        }
    ]
}'


curl -X DELETE \
  http://localhost:8181/restconf/config/ietf-access-control-list:access-lists/acl/ietf-access-control-list:ipv4-acl/ACL92-Reverse \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: b86749db-3744-6681-5d92-3b3333e3065c' \
  -d '{
    "acl": [
        {
            "acl-type": "ietf-access-control-list:ipv4-acl",
            "acl-name": "ACL92-Reverse",
            "access-list-entries": {
                "ace": [
                    {
                        "rule-name": "ACE92-1-Reverse",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 0
                            },
                            "destination-port-range": {
                                "lower-port": 0
                            },
                            "source-ipv4-network": "192.168.2.0/24",
                            "destination-ipv4-network": "192.168.2.210/32",
                            "protocol": 1
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP92-Reverse"
                        }
                    },
                    {
                        "rule-name": "ACE92-2-Reverse",
                        "matches": {
                            "source-port-range": {
                                "lower-port": 0
                            },
                            "destination-port-range": {
                                "lower-port": 80
                            },
                            "source-ipv4-network": "192.168.2.0/24",
                            "destination-ipv4-network": "192.168.2.210/32",
                            "protocol": 6
                        },
                        "actions": {
                            "service-function-acl:rendered-service-path": "RSP92-Reverse"
                        }
                    }
                ]
            }
        }
    ]
}'


curl -X POST \
  http://localhost:8181/restconf/operations/rendered-service-path:delete-rendered-path \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: 3f80c118-b0c5-7f33-dd17-5e65d651ba1b' \
  -d '{
	"input": {
        "name": "RSP92"
    }
}'

curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-classifier:service-function-classifiers/service-function-classifier/ServiceFunctionClassifier92 \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: b66876d1-7e6b-5b2c-57f6-82f64a8423b3' \
  -d '
{
  "service-function-classifier": [
    {
      "name": "ServiceFunctionClassifier92",
      "acl": {
        "type": "ietf-access-control-list:ipv4-acl",
        "name": "ACL92"
      },
      "scl-service-function-forwarder": [
        {
          "name": "Classifier1",
          "interface": "veth-br92"
        }
      ]
    }
  ]
}'


curl -X DELETE \
  http://localhost:8181/restconf/config/service-function-classifier:service-function-classifiers/service-function-classifier/ServiceFunctionClassifier92-Reverse \
  -H 'authorization: Basic YWRtaW46YWRtaW4=' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'postman-token: e023f9b4-2b85-6aa8-6b35-5b29397ffaa1' \
  -d '{
  "service-function-classifier": [
    {
      "name": "ServiceFunctionClassifier92-Reverse",
      "acl": {
        "type": "ietf-access-control-list:ipv4-acl",
        "name": "ACL92-Reverse"
      },
      "scl-service-function-forwarder": [
        {
          "name": "Classifier2",
          "interface": "veth-br92"
        }
      ]
    }
  ]
}'

#************************************************
# Configure Classifiers
#************************************************
cat > classifier1.sh << EOF
ip netns del app92
ovs-vsctl del-port br-sfc veth-br92
EOF

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} 'sudo bash -s -x ' < classifier1.sh


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

