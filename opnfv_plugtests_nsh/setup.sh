#!/bin/bash

# Creates the infrastructure needed to run a client/server vms
# plus a Fortigate in between, using Service Chaining with Tacker

# Networks
openstack network create private
openstack subnet create --subnet-range 192.168.0.0/24 --network private private_subnet

openstack network create mgmt
openstack subnet create --subnet-range 192.168.1.0/24 --network mgmt mgmt_subnet

# Security groups
openstack security group list|grep default|awk '{print $2}'|xargs -I[] openstack --insecure security group delete []
openstack security group rule create --protocol tcp --dst-port 22 default

# Images
wget http://artifacts.opnfv.org/sfc/images/sfc_nsh_fraser.qcow2
openstack image create --file fgt-nsh-6.0.qcow2 --disk-format=qcow2 fgt-nsh-6.0
openstack image create --file sfc_nsh_fraser.qcow2 --disk-format=qcow2 sfc-nsh-fraser

# Flavors
openstack flavor create --ram 1024 --disk 4 --vcpus 1 fortinet_small
openstack flavor create --ram 512 --disk 1 --vcpus 1 tiny

# Client and Server VMs
# Credentials: root/opnfv
openstack server create --flavor tiny --image sfc_nsh_fraser --nic net-id=private client
openstack server create --flavor tiny --image sfc_nsh_fraser --nic net-id=private server

# Fortigate VNF
pip install python-tackerclient==0.11.0

# Tacker
tacker vim-register --description "OpenStack XCI" --config-file vim.json openstack-xci

tacker vnfd-create --vnfd-file fgt-vnfd.yaml fgt-vnfd
tacker vnf-create --vim-name openstack-xci --vnfd-name fgt-vnfd fgt-vnf

tacker vnffgd-create --vnffgd-file fgt-vnffgd.yaml fgt-vnffgd 
tacker vnffg-create --vnffgd-name fgt_vnffgd fgt-vnfgg

