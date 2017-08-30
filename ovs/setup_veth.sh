#!/bin/bash

source /vagrant/env.sh
ip netns add app
ip link add veth-app type veth peer name veth-br
ovs-vsctl add-port br-sfc veth-br
ip link set dev veth-br up
ip link set veth-app netns app
host=`hostname`
if [ "${host}"  == "${CLASSIFIER1_NAME}" ] ; then
    ip netns exec app ifconfig veth-app 192.168.2.1/24 up
    ip netns exec app ip link set dev veth-app  addr 00:00:11:11:11:11
    ip netns exec app arp -s 192.168.2.2 00:00:22:22:22:22 -i veth-app
    ip netns exec app ip link set dev veth-app up
    ip netns exec app ip link set dev lo up
    ip netns exec app ifconfig veth-app mtu 1400
    ip netns exec app ethtool -K veth-app tx off

    ip netns add app2
    ip link add veth-app2 type veth peer name veth-br2
    ovs-vsctl add-port br-sfc veth-br2
    ip link set dev veth-br2 up
    ip link set veth-app2 netns app2

    ip netns exec app2 ifconfig veth-app2 192.168.2.129/24 up
    ip netns exec app2 ip link set dev veth-app2  addr 00:00:11:11:11:12
    ip netns exec app2 arp -s 192.168.2.2 00:00:22:22:22:22 -i veth-app2
    ip netns exec app2 ip link set dev veth-app2 up
    ip netns exec app2 ip link set dev lo up
    ip netns exec app2 ifconfig veth-app2 mtu 1400
    ip netns exec app2 ethtool -K veth-app2 tx off


fi

if [ "${host}"  == "${CLASSIFIER2_NAME}" ] ; then
    ip netns exec app ifconfig veth-app 192.168.2.2/24 up
    ip netns exec app ip link set dev veth-app  addr 00:00:22:22:22:22
    ip netns exec app arp -s 192.168.2.1 00:00:11:11:11:11 -i veth-app
    ip netns exec app arp -s 192.168.2.129 00:00:11:11:11:12 -i veth-app
    ip netns exec app ip link set dev veth-app up
    ip netns exec app ip link set dev lo up
    ip netns exec app ifconfig veth-app mtu 1400
    ip netns exec app ethtool -K veth-app tx off
    ip netns exec app python3 -m http.server 80
fi
ovs-vsctl show
