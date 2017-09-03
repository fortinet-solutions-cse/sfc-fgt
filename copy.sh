#!/usr/bin/env bash

source env.sh
set -x

cp ~/PycharmProjects/sfc-proxy/proxy.py .

rsync proxy.py ${SF2_PROXY_IP}:/vagrant/
rsync proxy.py ${SF3_PROXY_IP}:/vagrant/

rsync ./ovs/setup_sfc_proxy.sh ${SF2_PROXY_IP}:/vagrant/ovs/setup_sfc_proxy.sh
rsync ./ovs/setup_sfc_proxy.sh ${SF3_PROXY_IP}:/vagrant/ovs/setup_sfc_proxy.sh

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "nohup sudo /vagrant/ovs/setup_sfc_proxy.sh </dev/null >/dev/null 2>&1 &"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF3_PROXY_IP} "nohup sudo /vagrant/ovs/setup_sfc_proxy.sh </dev/null >/dev/null 2>&1 &"



