#!/bin/bash

source env.sh

virsh destroy sf2proxy
virsh destroy sf2

virsh start sf2proxy
virsh start sf2

sleep 20

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo nohup bash /vagrant/ovs/setup_sfc_proxy.sh 2>&1 >sf2proxy.log" &
