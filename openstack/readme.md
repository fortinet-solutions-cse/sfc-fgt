This version of scaling fortigate works in OpenStack Pike.

It is MPLS based and no NSH proxy is implemented for this version.

To run just execute:

./setup.sh

This will create a client vm and a server vm.
Access the server in 10.10.11.41 and run a web server:

ssh -i t1.pem ubuntu@10.10.11.41
sudo python -m SimpleHTTPServer 80

Now run in the host:
./scale_out.sh <random id between (2..9)> <CIDR of the new client>

e.g.:
./scale_in.sh 5 192.168.50.50/24

A new Fortigate will be booted up. And a chain will redirect traffic from the
client to server through this new Fortigate.

You can access now the client where a new network namespace 
has just been created and run:

ssh -i t1.pem ubuntu@10.10.11.40
sudo ip netns exec app_<id> wget 192.168.7.41

You should get an index.html reply from the server.

Check the Fortigate to see that traffic is going through it:

ssh admin@10.10.11.4<id>
diagnose sniffer packet port2

Once finished just run:

./scale_in_<id>.sh

This will destroy the Fortigate associated to this id and the chain associated.

Enjoy.
