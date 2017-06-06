#!/bin/bash

source /vagrant/env.sh
/vagrant/ovs/cleanup_sf_proxy.sh

INTFACE=eth0

python /vagrant/vxlan_tool.py -i ${INTFACE} --do=nsh_proxy -v on | tee ${HOME}/vxlan_tool.log
