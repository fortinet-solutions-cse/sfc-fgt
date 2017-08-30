#!/bin/bash

source env.sh

virsh destroy sf2proxy
virsh destroy sf2

virsh start sf2proxy
virsh start sf2

virsh destroy sf3proxy
virsh destroy sf3

virsh start sf3proxy
virsh start sf3

sleep 20

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo nohup bash /vagrant/ovs/setup_sfc_proxy.sh 2>&1 >sf2proxy.log" &

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF3_PROXY_IP} "sudo nohup bash /vagrant/ovs/setup_sfc_proxy.sh 2>&1 >sf2proxy.log" &
