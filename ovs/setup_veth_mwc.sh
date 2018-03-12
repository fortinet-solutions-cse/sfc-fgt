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

    # User 2
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

    # User 3
    ip netns add app3
    ip link add veth-app3 type veth peer name veth-br3
    ovs-vsctl add-port br-sfc veth-br3
    ip link set dev veth-br3 up
    ip link set veth-app3 netns app3

    ip netns exec app3 ifconfig veth-app3 192.168.3.100/24 up
    ip netns exec app3 ip link set dev veth-app3  addr 00:00:11:11:11:13
    ip netns exec app3 arp -s 192.168.2.2 00:00:22:22:22:22 -i veth-app3
    ip netns exec app3 ip link set dev veth-app3 up
    ip netns exec app3 ip link set dev lo up
    ip netns exec app3 ifconfig veth-app3 mtu 1400
    ip netns exec app3 ethtool -K veth-app3 tx off

    ip netns exec app3 ip route add 192.168.2.0/24 dev veth-app3

fi

if [ "${host}"  == "${CLASSIFIER2_NAME}" ] ; then
    ip netns exec app ifconfig veth-app 192.168.2.2/24 up
    ip netns exec app ip link set dev veth-app  addr 00:00:22:22:22:22
    ip netns exec app arp -s 192.168.2.1 00:00:11:11:11:11 -i veth-app
    ip netns exec app arp -s 192.168.2.129 00:00:11:11:11:12 -i veth-app
    ip netns exec app arp -s 192.168.3.100 00:00:11:11:11:13 -i veth-app
    ip netns exec app ip link set dev veth-app up
    ip netns exec app ip link set dev lo up
    ip netns exec app ifconfig veth-app mtu 1400
    ip netns exec app ethtool -K veth-app tx off
    ip netns exec app ip route add 192.168.3.0/24 dev veth-app
    ip netns exec app python3 -m http.server 80

fi
ovs-vsctl show
