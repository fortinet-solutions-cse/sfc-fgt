#### OpenStack Pike release ####
If you don’t have one already, generate an SSH key in $HOME/.ssh

ssh-keygen -t rsa

Clone OPNFV releng-xci repository

git clone https://gerrit.opnfv.org/gerrit/releng-xci.git
 
Change into directory where the sandbox script is located:
cd releng-xci/xci

Use a version of releng-xci which we know works

git checkout cf2cd4e4b87a5e392bc4ba49749a349925ba2f86

Set the sandbox flavor, OPNFV scenario, openstack version, VM size and releng_xci and bifrost versions:
export XCI_FLAVOR=mini 
export OPNFV_SCENARIO=os-odl-sfc
export OPENSTACK_OSA_VERSION=stable/pike
export VM_MEMORY_SIZE=16384
export OPENSTACK_BIFROST_VERSION=bd7e99bf7a00e4c9ad7d03d752d7251e3caf8509
 

Execute the sandbox script

./xci-deploy.sh
