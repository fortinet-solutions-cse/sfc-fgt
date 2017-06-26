export UBUNTU_IMAGE_URL=https://cloud-images.ubuntu.com/releases/14.04/release/ubuntu-14.04-server-cloudimg-amd64-disk1.img
export UBUNTU_IMAGE_NAME=$(basename ${UBUNTU_IMAGE_URL})

export OVS_LOG=/var/log/openvswitch/ovs-vswitchd.log
export DB_SOCK=/var/run/openvswitch/db.sock
export OVS_CONF_DB="/etc/openvswitch/conf.db"
export OVS_SCHEMA=/home/vagrant/ovs/vswitchd/vswitch.ovsschema
export DB_PIDFILE=/var/run/openvswitch/ovsdb-server.pid
export VSD_PIDFILE=/var/run/openvswitch/ovs-vswitchd.pid

export DPDK_DIR=/home/vagrant/dpdk-16.07
export DPDK_BUILD=$DPDK_DIR/x86_64-native-linuxapp-gcc/

export CLASSIFIER1_NAME=classifier1
export CLASSIFIER1_IP=192.168.60.10
export CLASSIFIER1_MAC=08:00:27:4c:60:10

export SFF1_NAME=sff1
export SFF1_IP=192.168.60.20
export SFF1_MAC=08:00:27:4c:60:20

export SF1_NAME=sf1
export SF1_IP=192.168.60.30
export SF1_MAC=08:00:27:4c:60:30

export SF2_NAME=sf2
export SF2_IP_ADMIN=192.168.122.40
export SF2_IP=192.168.70.40
export SF2_IP2=192.168.80.40
export SF2_MAC_ADMIN=08:00:27:4c:22:40
export SF2_MAC=08:00:27:4c:70:40
export SF2_MAC2=08:00:27:4c:80:40

export SFF2_NAME=sff2
export SFF2_IP=192.168.60.50
export SFF2_MAC=08:00:27:4c:60:50

export CLASSIFIER2_NAME=classifier2
export CLASSIFIER2_IP=192.168.60.60
export CLASSIFIER2_MAC=08:00:27:4c:60:60

export ODL_CONTROLLER=192.168.60.1
export LOCALHOST=127.0.0.1

export HC_CONFIG_DATA=/var/lib/honeycomb/persist/config/data.json
export HC_CONTEXT_DATA=/var/lib/honeycomb/persist/context/data.json

export CLASSIFIER1_NS_IP=192.168.2.1
export CLASSIFIER1_NS_MAC=0000.1111.1111
export CLASSIFIER2_NS_IP=192.168.2.2
export CLASSIFIER2_NS_MAC=0000.2222.2222

export SF2_PROXY_NAME=sf2proxy
export SF2_PROXY_IP=192.168.60.70
export SF2_PROXY_IP2=192.168.70.70
export SF2_PROXY_IP3=192.168.80.70
export SF2_PROXY_MAC=08:00:27:4c:60:70
export SF2_PROXY_MAC2=08:00:27:4c:70:70
export SF2_PROXY_MAC3=08:00:27:4c:80:70
