#!/bin/bash

source env.sh
vagrant destroy -f
vagrant box list|cut -d" " -f1|xargs -I[] vagrant box remove []
rm trusty-server-cloudimg-amd64-vagrant-disk1

virsh vol-list default|cut -d" " -f2 |xargs -I[] virsh vol-delete [] default

echo "******************"
echo "** FINAL STATUS **"
echo "******************"
vagrant status
vagrant global-status

virsh list
virsh vol-list default

ls -la /var/lib/libvirt/images/

