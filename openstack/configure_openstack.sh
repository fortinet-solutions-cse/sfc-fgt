#!/usr/bin/env bash


NEUTRON_EXT_NET_GW="10.10.10.1"
NEUTRON_EXT_NET_CIDR="10.10.10.0/23"

NEUTRON_EXT_NET_NAME="ext_net" # Unused
NEUTRON_DNS=$NEUTRON_EXT_NET_GW
NEUTRON_FLOAT_RANGE_START="10.10.10.12"
NEUTRON_FLOAT_RANGE_END="10.10.10.253"

NEUTRON_FIXED_NET_CIDR="192.168.16.0/24"

# Determine the tenant id for the configured tenant name.
export TENANT_ID="$(openstack project list | grep $OS_TENANT_NAME | awk '{ print $2 }')"

if [ "$TENANT_ID" = "" ]; then
	echo "Unable to find tenant ID, keystone auth problem"
	exit 2
fi

echo "Configuring Openstack Neutron Networking"

openstack network create --share --external --disable-port-security --provider-physical-network flat --provider-network-type flat ext_net
openstack subnet create --network ext_net \
  --allocation-pool start=$NEUTRON_FLOAT_RANGE_START,end=$NEUTRON_FLOAT_RANGE_END \
  --dns-nameserver $NEUTRON_DNS --gateway $NEUTRON_EXT_NET_GW \
  --subnet-range $NEUTRON_EXT_NET_CIDR ext_net_subnet

#Create mgmt network for neutron for tenant VMs
openstack network create --disable-port-security mgmt
openstack subnet create --network mgmt \
  --subnet-range $NEUTRON_FIXED_NET_CIDR mgmt_subnet

#Create router for external network and mgmt network
openstack router create provider-router
openstack router set --external-gateway ext_net provider-router
openstack router add subnet provider-router mgmt_subnet

openstack security group list -f value|awk '{print $1}'|xargs -I[] openstack --insecure security group delete []

#Configure the default security group to allow ICMP and SSH
openstack security group rule create --proto icmp default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 22 default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 80 default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 443 default || echo "should have been created already"
#port for RDP
openstack security group rule create --proto tcp --dst-port 3389 default || echo "should have been created already"


##make wide open
openstack security group rule create --proto tcp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --ingress default || echo "should have been created already"
openstack security group rule create --proto tcp --dst-port 1:65535  --egress default || echo "should have been created already"
openstack security group rule create --proto udp --dst-port 1:65535  --egress default || echo "should have been created already"


#Remove the m1.tiny as it is too small for Ubuntu.
for flavor in m1.tiny m1.small m1.medium m1.large m1.xlarge
do
openstack  flavor delete $flavor || true
done
openstack flavor create m1.small --id auto --ram 1024 --disk 20 --vcpus 1
openstack flavor create m1.medium --id auto --ram 2048 --disk 20 --vcpus 2
openstack flavor create m1.large --id auto --ram 4096 --disk 20 --vcpus 4

#Modify quotas for the tenant to allow large deployments
openstack quota  set --ram 204800 --cores 200 --instances 100 admin


#Upload images to glance
echo "Uploading images to glance"

wget http://cloud-images.ubuntu.com/trusty/current/trusty-server-cloudimg-amd64-disk1.img
openstack image show  "Trusty x86_64" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare --public  "Trusty x86_64"  --file  trusty-server-cloudimg-amd64-disk1.img
wget http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
openstack image show  "Trusty x86_64" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare --public  "Xenial x86_64"  --file  xenial-server-cloudimg-amd64-disk1.img
wget http://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
openstack image show  "Centos 7 x86_64" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare  --public  "Centos 7 x86_64"  --file  CentOS-7-x86_64-GenericCloud.qcow2
wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img
openstack image show  "Cirros 0.3.4" > /dev/null 2>&1 || openstack image create --disk-format qcow2 --container-format bare  --public  "Cirros 0.3.4"  --file  cirros-0.3.4-x86_64-disk.img