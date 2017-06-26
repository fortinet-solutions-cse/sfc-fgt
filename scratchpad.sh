
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
