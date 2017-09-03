#!/bin/bash

ifconfig eth1 up;
ifconfig eth2 up;
apt-get update
apt-get install -y python3-pip
pip3 install hexdump

pkill proxy.py
pkill tcpdump

tcpdump -i eth1 -l >/dev/null &

tcpdump -i eth2 -l >/dev/null &

ethtool -K eth1 tx off

ethtool -K eth2 tx off

ifconfig eth0 promisc
ifconfig eth1 promisc
ifconfig eth2 promisc

ifconfig eth0 mtu 4096
ifconfig eth1 mtu 4096
ifconfig eth2 mtu 4096


/vagrant/proxy.py --encap_if eth0 --unencap_in_if eth2 --unencap_out_if eth1 2>&1 >proxy.log &

