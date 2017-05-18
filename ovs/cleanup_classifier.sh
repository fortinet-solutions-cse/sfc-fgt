#!/bin/bash

source /vagrant/env.sh
/vagrant/ovs/cleanup_veth.sh
rm -f ${OVS_CONF_DB}
rm -f /var/log/honeycomb/honeycomb.log
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
