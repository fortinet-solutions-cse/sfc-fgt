#!/usr/bin/bash
#To be done in ubuntu 16.04.2LTS

sudo apt-get install -y  openjdk-8-jdk
sudo apt-get install -y qemu-kvm libvirt-bin libguestfs-tools


#Manual
#Generate public key in default dir (~/.ssh/id_rsa.pub)





#Optional
sudo apt-get install -y virt-manager


#TODO: Remove this and put it in the right place
#For VM SF2_PROXY

sudo apt-get install -y python3-pip
sudo pip3 install hexdump

#Checks


#Things done
set etc/sysctl.conf: ipv4.forward (uncomment)

sudo brctl setageing virbr2 0
sudo brctl setageing virbr3 0