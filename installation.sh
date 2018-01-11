#!/bin/bash
#To be done in ubuntu 16.04.2LTS

sudo apt-get install -y  openjdk-8-jdk
sudo apt-get install -y qemu-kvm libvirt-bin libguestfs-tools virtinst
sudo apt-get install -y sshpass wget curl openssh-client xterm

#Manual
#Generate public key in default dir (~/.ssh/id_rsa.pub)

#Optional
sudo apt-get install -y virt-manager

# Things done
# Check this: set etc/sysctl.conf: ipv4.forward (uncomment)
