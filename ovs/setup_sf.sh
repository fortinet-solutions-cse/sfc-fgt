#!/bin/bash

source /vagrant/env.sh
INTFACE=eth0

python /vagrant/vxlan_tool.py -i ${INTFACE} --do=forward -v on | tee ${HOME}/vxlan_tool.log
