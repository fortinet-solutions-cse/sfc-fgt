# OpenStack Pike deployment with OpenDayLight

This is intended to deploy an OpenStack environment with OpenDayLight.

Use it as a testbed for SFC/NSH.

These instructions are extracted from this page:

https://wiki.opnfv.org/display/sfc/Deploy+OPNFV+SFC+scenarios



## Steps

If you don’t have one already, generate an SSH key in $HOME/.ssh

```
ssh-keygen -t rsa
```
Clone OPNFV releng-xci repository

```
git clone https://gerrit.opnfv.org/gerrit/releng-xci.git
```
Change into directory where the sandbox script is located:

```
cd releng-xci/xci
```

Use a version of releng-xci which we know works

```
git checkout 7c37b9ac8715ebedecf903f9de67c55830fb5b90
```

Set the sandbox flavor, OPNFV scenario, openstack version, VM size and releng_xci and bifrost versions:

```
export XCI_FLAVOR=mini
export DEPLOY_SCENARIO=os-odl-sfc
export VM_MEMORY_SIZE=16384
export OPENSTACK_OSA_VERSION=stable/pike
export OPENSTACK_BIFROST_VERSION=f3cf0d9fff6ec08ba0e46cbde5bfebfd77a26752
export BIFROST_IRONIC_VERSION=9b8440aa318e4883a74ef8640ad5409dd22858a9
export BIFROST_IRONIC_CLIENT_VERSION=1da269b0e99601f8f6395b2ce3f436f5600e8140
export BIFROST_IRONIC_INSPECTOR_VERSION=84da941fafb905c2debdd9a9ba68ba743af3ce8a
export BIFROST_IRONIC_INSPECTOR_CLIENT_VERSION=b73403fdad3165cfcccbf4b0330d426ae5925e01
```

Execute the sandbox script

```
./xci-deploy.sh
```
