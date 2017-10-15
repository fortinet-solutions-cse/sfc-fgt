#!/usr/bin/env bash
##Not idempotent! Be Careful!

juju run --application neutron-api,nova-compute "sudo apt -y install zile"
juju run --application neutron-api,nova-compute "export LC_ALL=C; sudo pip install -c https://git.openstack.org/cgit/openstack/requirements/plain/upper-constraints.txt?h=stable/newton networking-sfc==3.0.0"

juju ssh neutron-api/0 sudo sed -i.old \"s/service_plugins = router,firewall,vpnaas,metering,neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2/service_plugins = router,firewall,vpnaas,metering,neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2,networking_sfc.services.flowclassifier.plugin.FlowClassifierPlugin,networking_sfc.services.sfc.plugin.SfcPlugin/\" /etc/neutron/neutron.conf

juju ssh neutron-api/0 echo -e "\\\n\\\n[sfc]\\\ndrivers = ovs\\\n\\\n[flowclassifier]\\\ndrivers = ovs\\\n\\\n | sudo tee -a /etc/neutron/neutron.conf"

juju ssh neutron-api/0 sudo systemctl restart neutron-server

juju ssh nova-compute/0 sudo sed -i.old \"s/\\[agent\\]/\\[agent\\]\\nextensions = sfc/\" /etc/neutron/plugins/ml2/openvswitch_agent.ini

juju ssh nova-compute/0 sudo systemctl restart neutron-openvswitch-agent

juju ssh nova-compute/1 sudo sed -i.old \"s/\\[agent\\]/\\[agent\\]\\nextensions = sfc/\" /etc/neutron/plugins/ml2/openvswitch_agent.ini

juju ssh nova-compute/1 sudo systemctl restart neutron-openvswitch-agent

juju ssh neutron-api/0 sudo neutron-db-manage --subproject networking-sfc upgrade head
