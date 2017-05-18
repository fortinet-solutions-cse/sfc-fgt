#!/bin/bash

source /vagrant/env.sh
ifconfig eth2 0 down
INTFACE=eth1

python /vagrant/vxlan_tool.py -i ${INTFACE} --do=forward -v on | tee /home/vagrant/vxlan_tool.log
