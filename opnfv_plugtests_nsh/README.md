Instructions
============

This set of scripts help on deploying a FortiGate with NSH support in an OpenStack environment.
The environment is based on Tacker, Networking SFC, OpenVSwitch and OpenDayLight.

1. Please go to https://wiki.opnfv.org/display/sfc/Deploy+OPNFV+SFC+scenarios and follow instructions to install OPNFV XCI.

1.1 Immediately after cloning releng-xci repository and before starting XCI installation please make sure you select the commit below, as it contains a valid and working procedure to install XCI:

`git checkout c1ef2d45fe71dda92ec2f015b2ccd70ce2855d85`

2. After a couple hours you will get an OpenStack environment in one single Vm.

Internally you will see three or more VMs

opnfv:      ssh root@192.168.122.2
controller: ssh root@192.168.122.3
computes:   ssh root@192.168.122.4 (.5, .6, etc.)

3. Go to OPNFV VM and clone this repo

`ssh root@192.168.122.2`

git clone https://github.com/fortinet-solutions-cse/sfc-fgt.git

4. Navigate to:

`cd sfc-fgt/opnfv_plugtests_nsh/`

5. Make sure you have an image of FortiGate with NSH support. Name it: fgt-nsh-6.0.qcow2

`scp 192.168.122.1:/root/fgt-nsh-6.0.qcow2 .`
(This assumes the image is already in the host)

6. Copy openrc file from home to this directory

`cp ~/openrc .`

7. Run setup script

`./setup.sh`

This will bring up everything needed to run the test: A FortiGate and a couple of VMs to act as server and client.
Also the proper VNFD, VNFFG and others are created to have the traffic going through the chain.
Fortigate is also loaded with proper configuration.

8. Run status to get a snapshot of current deployment:

`./status.sh`

9. Delete everything with cleanup.

`./cleanup.sh`

Access FortiGate and VMs console
================================

1. Go to controller and get the available namespaces

`ssh root@192.168.122.3`
`ip netns`

One of the namespaces is for mgmt network in FortiGate. The other is for traffic network and can be used to access client and server VMs.

2. Run this command to show which network namespace contains each network:

`for x in $(ip netns); do echo -n $x;ip netns exec $x ifconfig|grep 192; done`

Typical output:

qdhcp-f6e3af43-062a-445c-ac68-02a2bd8067bc          inet addr:192.168.1.2  Bcast:192.168.1.255  Mask:255.255.255.0
qdhcp-d0f91b60-7ad4-4929-bf47-db351188b7e4          inet addr:192.168.0.2  Bcast:192.168.0.255  Mask:255.255.255.0

3. Depending on the VM you want to access (check IPs by running `openstack server list` in OPNFV vm) select the proper namespace and access it:

E.g. if Fortigate has its mgmt IP in 192.168.1.9 run:

`ip netns exec qdhcp-f6e3af43-062a-445c-ac68-02a2bd8067bc bash`
`ssh admin@192.168.1.9`


Bonus: Activate Horizon
=======================

If Horizon does not work, there is a workaround to have it working.

1. Go to OPNFV VM

`ssh root@192.168.122.2`

2. Edit below file and change "haproxy_ssl: false" to "haproxy_ssl: true"

`vi /etc/openstack_deploy/user_variables.yml`

3. Go to:

`cd releng-xci/.cache/repos/openstack-ansible/playbooks/`

4. Execute:

`openstack-ansible haproxy-install.yml`
 
5. Now horizon should work, but this change breaks the rest of services. Copy the haproxy from controller.

`ssh root@192.168.122.3`

`vi  /etc/haproxy/haproxy.cfg`
(copy the part between "# Ansible managed" tags that contains horizon config)

5.1 Or alternatively use:

`cat /etc/haproxy/haproxy.cfg | nc termbin.com 9999`
(use the returned url to get access to the file)

6. Go back to OPNFV VM and revert the previous change "haproxy_ssl: false"

`vi /etc/openstack_deploy/user_variables.yml`

7. Execute the ansible playbook

`cd 'releng-xci/.cache/repos/openstack-ansible/playbooks/`

`openstack-ansible haproxy-install.yml`

8. Again, in controller open the haproxy.cfg file and modify only the horizon config with the one obtained from step 5.

`ssh root@192.168.122.3`

`vi  /etc/haproxy/haproxy.cfg`

9. Restart haproxy service (in controller).

`systemctl restart haproxy.service`
