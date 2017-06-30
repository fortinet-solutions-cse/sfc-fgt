#!/bin/bash

source env.sh

alias ssh='ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app wget -t1 http://192.168.2.2/"

declare -A VM_IP=( [${CLASSIFIER1_NAME}]=${CLASSIFIER1_IP} \
   [${SFF1_NAME}]=${SFF1_IP} \
   [${SF1_NAME}]=${SF1_IP} \
   [${SFF2_NAME}]=${SFF2_IP} \
   [${SF2_PROXY_NAME}]=${SF2_PROXY_IP} \
   [${CLASSIFIER2_NAME}]=${CLASSIFIER2_IP})

for VM_NAME in ${!VM_IP[@]};
do
   echo -e "\n${VM_NAME} configuration"
   echo "================================="
   ssh ${VM_IP[${VM_NAME}]} 'sudo ovs-vsctl show'
   echo -e "\n${VM_NAME} OopenFlow Rules"
   echo "================================="
   ssh ${VM_IP[${VM_NAME}]} 'sudo ovs-ofctl dump-flows br-sfc'
   echo -e "\n${VM_NAME} Data Path Flows"
   echo "================================="
   ssh ${VM_IP[${VM_NAME}]} 'sudo ovs-dpctl dump-flows'

done
