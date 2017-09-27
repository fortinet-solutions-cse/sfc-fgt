
sudo ../PycharmProjects/nsh-proxy/proxy.py --encap_if vnet5 --unencap_in_if vnet10 --unencap_out_if vnet9
sudo /vagrant/proxy.py --encap_if eth0 --unencap_in_if eth2 --unencap_out_if eth1


ssh admin@192.168.122.40

#************************************************
# Start Fake FW
#************************************************
virsh destroy sf2
virsh undefine sf2

virt-install --connect qemu:///system --noautoconsole --filesystem ${PWD},shared_dir --import --name ${SF2_NAME} --ram 2024 --vcpus 1 --disk sf2.img,size=3 --disk ${SF2_NAME}-cidata.iso,device=cdrom --network bridge=virbr1,mac=${SF2_MAC}



rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -r -v --max-size=1048576 ./*  ${SF2_PROXY_IP}:/vagrant/

cp ../PycharmProjects/nsh-proxy/proxy.py .;rsync -e "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no" -r -v --max-size=1048576 ./*  ${SF2_PROXY_IP}:/vagrant/;ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "sudo nohup bash /vagrant/ovs/setup_sfc_proxy.sh 2>&1 >sf2proxy.log" &



config system interface
edit port1
set ip 192.168.122.40/24
end

config system interface
edit port2
set ip 192.168.60.40/24
end

config system vxlan
edit vxlan3
set vni 1
set remote-ip 192.168.160.70
set dstport 4789
set interface port3
end

config system vxlan
edit vxlan1
set vni 1
set remote-ip 192.168.60.70
set dstport 4789
set interface port2
end


config system vxlan
edit vxlan2
set vni 2
set remote-ip 192.168.170.70
set dstport 4789
set interface port3
end

config system interface
edit vxlan1
set ip 192.168.2.2/24
end

config system interface
edit vxlan2
set ip 192.168.2.1/24
end





diagnose sys vxlan fdb list vxlan1

diag sniffer packet port3


diag debug enable
diag debug flow filter add 192.168.2.2
#diag debug flow show console enable
diag debug flow trace start 100
diag debug enable


diag debug application httpsd -1 (FYI)


""""""""""
sudo brctl setageing virbr2 0
sudo brctl setageing virbr3 0

diagnose netlink brctl list
diagnose netlink brctl name host vwp1_v.b



config system settings
set multicast-skip-policy enable
end

config system interface
edit "port2"
set broadcast-forward enable
next


config firewall multicast-policy
edit 1
set action accept
next
end

config firewall multicast-policy
edit 1
set action accept
set srcintf port2
set dstintf port2
set srcaddr 0.0.0.0
set dstaddr 0.0.0.0
next
end


config system session-ttl
   set default 0
     config port
       edit 443
         set protocol 6
         set timeout 3600
         set end-port 443
         set start-port 443
        next
      end
end

""""""""""""

config system interface
edit "port2"
set broadcast-forward enable
next
end


FortiGate-VM64-KVM (vxlan1) # 0800
                                  IP Version: 4 IP Header Length: 5, TTL: 64, Protocol: 17, Src IP: 192.168.60.50, Dst IP: 192.168.60.70
                           UDP Src Port: 49289, Dst Port: 4790, Length: 152, Checksum: 41913
                                                                                            VxLAN/VxLAN-gpe VNI: 0, flags: 0c, Next: 3
                         NSH base nsp: 37, nsi: 253
                                                   NSH context c1: 0x00000004, c2: 0x00000000, c3: 0xc0a83c28, c4: 0x00000000


Received Packet #79
   Eth Dst MAC: 08:00:27:4c:60:70, Src MAC: 08:00:27:4c:60:40, Ethertype: 0x0800
   IP Version: 4 IP Header Length: 5, TTL: 64, Protocol: 17,
   Src IP: 192.168.60.40, Dst IP: 192.168.60.70
   UDP Src Port: 4789, Dst Port: 4789, Length: 58, Checksum: 19303
   VxLAN/VxLAN-gpe VNI: 1, flags: 08, Next: 0
   NSH base nsp: 16777134, nsi: 101
   NSH context c1: 0x75cf3564, c2: 0x08060001, c3: 0x08000604, c4: 0x0001ae65
                                                                                                 sf_ip = 8.0.6.4




cat >test <<EOF
<network>
  <name>test</name>
  <bridge name='test' stp='off' delay='0'/>
  <mac address='52:54:00:79:34:17'/>
  <ip address='192.168.90.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.90.2' end='192.168.90.254'/>
      <host mac='00:22:33:44:55:10' name='tap1' ip='192.168.90.10'/>
      <host mac='00:22:33:44:55:20' name='tap2' ip='192.168.90.20'/>
    </dhcp>
  </ip>
</network>
EOF

sudo virsh net-create test


sudo wireshark -i vnet9 &
sudo wireshark -i vnet7 &
sudo wireshark -i vnet8 &
sudo wireshark -i vnet10 &


sudo wireshark -i vnet5 &



virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name sff2 --file sff2.img --mac=${SFF2_MAC}
sudo virt-sysprep -a sff2.img --hostname sff2 --firstboot-command 'sudo ssh-keygen -A'




VM_NAME=sff2
   virt-clone --connect qemu:///system --original ${CLASSIFIER1_NAME} --name ${VM_NAME} --file ${VM_NAME}.img --mac=${VM_MAC[${VM_NAME}]}
   if [ $? -ne 0 ]; then
     echo "Error cloning image. Aborting"
     exit -1
   fi

   sleep 3

   sudo virt-sysprep -a ${VM_NAME}.img --hostname ${VM_NAME} --firstboot-command 'sudo ssh-keygen -A'

   cat >meta-data <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

   rm -rf ${VM_NAME}-cidata.iso
   genisoimage -output ${VM_NAME}-cidata.iso -volid cidata -joliet -rock user-data meta-data
   chmod 666 ${VM_NAME}-cidata.iso

   virsh change-media ${VM_NAME} hdb --eject --config --force
   virsh change-media ${VM_NAME} hdb ${PWD}/${VM_NAME}-cidata.iso --insert --config --force







#===========================
#Networking SFC commands
#===========================

neutron net-create netM --provider:network_type vxlan
neutron subnet-create --name netM_subnet netM 192.168.7.0/24

#image creation

neutron port-create --name p1M netM
neutron port-create --name p2M netM
neutron port-create --name p3M netM
neutron port-create --name p4M netM
neutron port-create --name p5M netM
neutron port-create --name p6M netM

p1Mid=$(neutron port-list|grep p1M|awk  '{print $2}')
p2Mid=$(neutron port-list|grep p2M|awk  '{print $2}')
p3Mid=$(neutron port-list|grep p3M|awk  '{print $2}')
p4Mid=$(neutron port-list|grep p4M|awk  '{print $2}')
p5Mid=$(neutron port-list|grep p5M|awk  '{print $2}')
p6Mid=$(neutron port-list|grep p6M|awk  '{print $2}')


openstack keypair create  t1 >t1.pem

openstack flavor create --ram 512 --disk 8 --vcpus 1 m1.smaller
openstack flavor create --ram 512 --disk 1 --vcpus 1 m1.tiny

nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$p1Mid --nic port-id=$p2Mid --key-name t1 vm1M
nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$p3Mid --nic port-id=$p4Mid --key-name t1 vm2M
nova boot --flavor m1.smaller --image "Trusty x86_64" --nic net-name=mgmt --nic port-id=$p5Mid --nic port-id=$p6Mid --key-name t1 vm3M


neutron flow-classifier-create --ethertype IPv4 --source-ip-prefix 192.168.7.13/32  --destination-ip-prefix 192.168.7.15/32  --protocol tcp  --source-port 23:65535  --destination-port 80:80 --logical-source-port p2M --logical-destination-port p5M fc1M 

neutron port-pair-create --ingress=p1M --egress=p2M pp1M
neutron port-pair-create --ingress=p3M --egress=p4M pp2M
neutron port-pair-create --ingress=p5M --egress=p6M pp3M

neutron port-pair-group-create --port-pair pp1M --port-pair pp2M pg1M
neutron port-pair-group-create --port-pair pp3M pg2M

neutron port-chain-create --port-pair-group pg1M --port-pair-group pg2M --flow-classifier fc1M pc1M



--- Status ---

neutron subnet-list
neutron net-list

nova list

neutron flow-classifier-list
neutron port-pair-list
neutron port-pair-group-list
neutron port-chain-list

--- Delete ---
neutron port-chain-delete pc1M

neutron port-pair-group-delete pg2M
neutron port-pair-group-delete pg1M

neutron port-pair-delete pp3M
neutron port-pair-delete pp2M
neutron port-pair-delete pp1M

neutron flow-classifier-delete fc1M

nova delete vm3M
nova delete vm2M
nova delete vm1M

neutron port-delete p6M
neutron port-delete p5M
neutron port-delete p4M
neutron port-delete p3M
neutron port-delete p2M
neutron port-delete p1M

--- Scratch ---

nova boot --flavor m1.tiny --image "Cirros 0.3.4" --nic net-name=netM --key-name t1 testVM
nova boot --flavor m1.medium --image "Trusty x86_64" --nic net-name=netM --key-name t1 test2VM


