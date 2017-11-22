#!/bin/bash

source /vagrant/env.sh
/vagrant/ovs/cleanup_veth.sh
/vagrant/ovs/stop_ovs_dpdk.sh
/vagrant/ovs/start_ovs.sh
/vagrant/ovs/setup_veth_mwc.sh & sleep 1
