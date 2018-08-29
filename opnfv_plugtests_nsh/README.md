Instructions
============

This set of scripts help on deploying a FortiGate with NSH support in an OpenStack environment.
The environment is based on Tacker, Networking SFC, OpenVSwitch and OpenDayLight.

1. Please go to https://wiki.opnfv.org/display/sfc/Deploy+OPNFV+SFC+scenarios and follow instructions to install OPNFV XCI.<br><br>
**Important**: Immediately after cloning releng-xci repository and before starting XCI installation please make sure you select the commit below, as it contains a valid and working procedure to install XCI:<br><br>
`git checkout c1ef2d45fe71dda92ec2f015b2ccd70ce2855d85`<br><br>
2. After a couple hours you will get an OpenStack environment in one single Vm.<br><br>
Internally you will see three or more VMs<br><br>
opnfv:      ssh root@192.168.122.2<br>
controller: ssh root@192.168.122.3<br>
computes:   ssh root@192.168.122.4 (.5, .6, etc.)<br><br>
3. Go to OPNFV VM and clone this repo<br><br>
`ssh root@192.168.122.2`<br><br>
`git clone https://github.com/fortinet-solutions-cse/sfc-fgt.git`<br><br>
4. Navigate to:<br><br>
`cd sfc-fgt/opnfv_plugtests_nsh/`<br><br>
5. Make sure you have an image of FortiGate with NSH support. Name it: fgt-nsh-6.0.qcow2<br><br>
`scp your_user@192.168.122.1:/your_home_path/fgt-nsh-6.0.qcow2 ~/sfc_fgt/opnfv_plugtests_nsh/`<br><br>
(This command assumes the image is already in your host from where you installed XCI)<br><br>
6. Copy openrc file from home to this directory:<br><br>
`cp ~/openrc .`<br><br>
7. Run setup script<br><br>
`./setup.sh`<br><br>
This will bring up everything needed to run the test: A FortiGate and a couple of VMs to act as server and client.
Also the proper VNFD, VNFFG and others are created to have the traffic going through the chain.
Fortigate is also loaded with proper configuration.<br><br>
8. Run status to get a snapshot of current deployment:<br><br>
`./status.sh`<br><br>
9. Delete everything with cleanup.<br><br>
`./cleanup.sh`<br><br>
## Access FortiGate and VMs console
1. Go to controller and get the available namespaces<br><br>
`ssh root@192.168.122.3`<br><br>
`ip netns`<br><br>
One of the namespaces is for mgmt network in FortiGate. The other is for traffic network and can be used to access client and server VMs.<br><br>
2. Run this command to show which network namespace contains each network:<br><br>
`for x in $(ip netns); do echo -n $x;ip netns exec $x ifconfig|grep 192; done`<br><br>
Typical output:<br><br>
qdhcp-f6e3af43-062a-445c-ac68-02a2bd8067bc          inet addr:192.168.1.2  Bcast:192.168.1.255  Mask:255.255.255.0<br><br>
qdhcp-d0f91b60-7ad4-4929-bf47-db351188b7e4          inet addr:192.168.0.2  Bcast:192.168.0.255  Mask:255.255.255.0<br><br>
3. Depending on the VM you want to access (check IPs by running `openstack server list` in OPNFV vm) select the proper namespace and access it:<br><br>
E.g. if Fortigate has its mgmt IP in 192.168.1.9 run:<br><br>
`ip netns exec qdhcp-f6e3af43-062a-445c-ac68-02a2bd8067bc bash`<br><br>
`ssh admin@192.168.1.9`<br><br>
## Bonus: Activate Horizon
If Horizon does not work, there is a workaround to have it working.<br><br>
1. Go to OPNFV VM<br><br>
`ssh root@192.168.122.2`<br><br>
2. Edit below file and change "haproxy_ssl: false" to "haproxy_ssl: true"<br><br>
`vi /etc/openstack_deploy/user_variables.yml`<br><br>
3. Go to:<br><br>
`cd releng-xci/.cache/repos/openstack-ansible/playbooks/`<br><br>
4. Execute:<br><br>
`openstack-ansible haproxy-install.yml`<br><br>
5. Now horizon should work, but this change breaks the rest of services. Copy the haproxy from controller.<br><br>
`ssh root@192.168.122.3`<br><br>
`vi  /etc/haproxy/haproxy.cfg`<br><br>
(copy the part between "# Ansible managed" tags that contains horizon config)<br><br>
Or alternatively use:<br><br>
`cat /etc/haproxy/haproxy.cfg | nc termbin.com 9999`<br><br>
(use the returned url to get access to the file)<br><br>
6. Go back to OPNFV VM and revert the previous change "haproxy_ssl: false"<br><br>
`vi /etc/openstack_deploy/user_variables.yml`<br><br>
7. Execute the ansible playbook<br><br>
`cd 'releng-xci/.cache/repos/openstack-ansible/playbooks/`<br><br>
`openstack-ansible haproxy-install.yml`<br><br>
8. Again, in controller open the haproxy.cfg file and modify only the horizon config with the one obtained from step 5.<br><br>
`ssh root@192.168.122.3`<br><br>
`vi  /etc/haproxy/haproxy.cfg`<br><br>
9. Restart haproxy service (in controller).<br><br>
`systemctl restart haproxy.service`<br><br>
