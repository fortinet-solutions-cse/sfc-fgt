#!/bin/bash
set -x 
root_dir=$(dirname $0)

nshproxy=true

if [ "${root_dir}" != "." ] ; then
    echo "Please run ./run_demo.sh $@"
    exit -1
fi

demo="./ovs/run_demo_ovs.sh"
features="odl-sfc-ui"
uninstall_features=""

demo="./ovs/run_demo_ovs.sh"
features="${features} odl-sfc-scf-openflow odl-sfc-openflow-renderer"
uninstall_features="odl-sfc-vpp-renderer"

#Install sshpass
toolscheck=$(exec 2>/dev/null;which sshpass && which wget && which curl && which ssh)
if [ $? -ne 0 ] ; then
    yum=$(which yum 2>/dev/null)
    if [ $? -eq 0 ] ; then
        sudo yum install -y sshpass wget curl openssh-clients
    fi

    aptget=$(which apt-get 2>/dev/null)
    if [ $? -eq 0 ] ; then
        sudo apt-get install -y sshpass wget curl openssh-client
    fi
fi

source ./env.sh

#Check if SFC is started
karaf=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} system:name)
if [ $? -ne 0 ] ;  then
    echo "Please start ODL SFC first."
    exit -1
fi

echo "Install and wait for sfc features: ${features}"
#Uninstall unnecessary features automatically
sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} feature:uninstall ${uninstall_features}

#Install necessary features automatically
sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} feature:install odl-restconf ${features}
retries=6
while [ $retries -gt 0 ]
do
    installed=0
    installed_features=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} feature:list -i | grep sfc | awk '{print $1;}')
    echo "Installed features: ${installed_features}"
    echo "Expected features: ${features}"
    i=0
    j=0
    for feature in ${features}
    do
        i=$((i+1))
        if [[ ${installed_features} =~ $feature ]] ; then
            j=$((j+1))
        fi
    done
    if [ $i -eq $j ] ; then
        installed=1
        break
    fi
    echo "Waiting for ${features} installed..."
    sleep 10
    retries=$((retries-1))
done

if [ $installed -ne 1 ] ; then
    echo "Failed to install features: ${features}"
    exit -1
fi

# For OVS and OVS_DPDK use case, must make sure renderer and classifier are intialized successfully
retries=10
while [ $retries -gt 0 ]
do
    OK=0
    result=$(curl -H "Content-Type: application/json" -H "Cache-Control: no-cache" -X GET --user admin:admin http://${LOCALHOST}:8181/restconf/operational/network-topology:network-topology/)
    OK=$((OK+$?))
    result=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} display | grep "successfully started the SfcOfRenderer")
    OK=$((OK+$?))
    result=$(sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf ${LOCALHOST} display | grep "successfully started the SfcScfOfRenderer")
    OK=$((OK+$?))
    if [ $OK -eq 0 ] ; then
        break
    fi
    echo "Waiting Openflow renderer and classifier initialized..."
    sleep 3
    retries=$((retries-1))
done

if [ $retries -eq 0 ] ; then
    echo "features are not started correctly: ${features}"
    exit -1
fi

./cleanup_demo.sh

HTTPPROXY="${http_proxy}"
HTTPSPROXY="${https_proxy}"

if [ "${HTTP_PROXY}" != "" ] ; then
    HTTPPROXY=${HTTP_PROXY}
fi
if [ "${HTTPS_PROXY}" != "" ] ; then
    HTTPSPROXY=${HTTPS_PROXY}
fi
if [ "${HTTPPROXY}" == "" ] ; then
    HTTPPROXY=${HTTPSPROXY}
fi
if [ "${HTTPSPROXY}" == "" ] ; then
    HTTPSPROXY=${HTTPPROXY}
fi

if [ ! -e ./${UBUNTU_VBOX_IMAGE} ] ; then
    wget ${UBUNTU_VBOX_URL}
fi

VBoxManage setextradata global VBoxInternal/CPUM/SSE4.1 1
VBoxManage setextradata global VBoxInternal/CPUM/SSE4.2 1

### Halt current VMS in order to clean up dirty environment

vagrant halt -f

### Just install one VM once but cloned for all the rest VMs ###
vagrant up ${CLASSIFIER1_NAME} --provider virtualbox
vagrant ssh ${CLASSIFIER1_NAME} -c "if [ -x /usr/lib/openvswitch-switch-dpdk/ovs-vswitchd -a -x /home/vagrant/ovs/vswitchd/ovs-vswitchd ] ; then exit 0; else exit -1; fi"
if [ $? -ne 0 ] ; then
    vagrant ssh ${CLASSIFIER1_NAME} -c "sudo /vagrant/ovs/install_ovs.sh ${HTTPPROXY} ${HTTPSPROXY}"
    if [ $? -ne 0 ] ; then
        echo "Failed to install ovs on ${CLASSIFIER1_NAME}"
        exit -1
    fi
    vagrant ssh ${CLASSIFIER1_NAME} -c "if [ -x /usr/lib/openvswitch-switch-dpdk/ovs-vswitchd -a -x /home/vagrant/ovs/vswitchd/ovs-vswitchd ] ; then exit 0; else exit -1; fi"
    if [ $? -eq 0 ] ; then
        vagrant package --output ./${UBUNTU_VBOX_IMAGE}.ready ${CLASSIFIER1_NAME}
        vagrant halt -f
        vagrant destroy -f
        vagrant box remove -f ${UBUNTU_VBOX_NAME}
        rm -rf ./.vagrant
        mv -f ./${UBUNTU_VBOX_IMAGE}.ready ./${UBUNTU_VBOX_IMAGE}
    fi
fi

vagrant up

vagrant ssh ${CLASSIFIER1_NAME} -c "sudo /vagrant/ovs/setup_classifier_ovs.sh"

vagrant ssh ${SFF1_NAME} -c "sudo /vagrant/ovs/setup_sff_ovs.sh"

vagrant ssh ${SF1_NAME} -c "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1"

vagrant ssh ${SF2_NAME} -c "sudo nohup /vagrant/ovs/setup_sf.sh & sleep 1"

vagrant ssh ${SFF2_NAME} -c "sudo /vagrant/ovs/setup_sff_ovs.sh"

vagrant ssh ${CLASSIFIER2_NAME} -c "sudo /vagrant/ovs/setup_classifier_ovs.sh"

if [ $nshproxy = true ] ; then
        ./ovs/setup_sfc_proxy.py
        vagrant ssh ${SF2_PROXY_NAME} -c "sudo nohup /vagrant/ovs/setup_sf_proxy.sh & sleep 1"
else
        ./ovs/setup_sfc.py
fi

vagrant ssh ${CLASSIFIER1_NAME} -c "sudo ip netns exec app ping -c 5 192.168.2.2"
vagrant ssh ${CLASSIFIER2_NAME} -c "sudo ip netns exec app python -m SimpleHTTPServer 80 &" 
vagrant ssh ${CLASSIFIER1_NAME} -c "sudo ip netns exec app wget http://192.168.2.2/"

