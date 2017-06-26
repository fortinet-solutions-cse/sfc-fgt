NFV Fortigate with SFC demo
===========================


Topology
-------

                                +-----------------+
                                | Host (ODL SFC)  |
                                |  192.168.60.1   |
                                +-----------------+
                            /      |          |     \
                         /         |          |         \
                     /             |          |             \
     +---------------+  +--------------+   +--------------+  +---------------+
     |  classifier1  |  |    sff1      |   |     sff2     |  |  classifier2  |
     | 192.168.60.10 |  |192.168.60.20 |   |192.168.60.50 |  | 192.168.60.60 |
     +---------------+  +--------------+   +--------------+  +---------------+
                                  |          |
                                  |          |
                        +---------------+  +--------------+
                        |  sf1(DPI-1)   |  |   sf2proxy   |
                        |192.168.60.30  |  |192.168.60.70 |
                        +---------------+  +--------------+
                                              |
                                              |
                                           +--------------+
                                           |   sf2(FGT)   |
                                           |192.168.60.40 |
                                           +--------------+

Setup Demo
----------
Note this demo should run on ubuntu 16.04 LTS

   1. Download OpenDayLight Carbon Release:

      wget https://nexus.opendaylight.org/content/repositories/public/org/opendaylight/integration/distribution-karaf/0.6.0-Carbon/distribution-karaf-0.6.0-Carbon.tar.gz

   2. Unpack ODL in a different directory of your choice:

      tar xvfz nfv-fgt/distribution-karaf-0.6.0-Carbon.tar.gz -C ..

   3. Copy karaf file to ODL base dir:

      cp karaf ../distribution-karaf-0.6.0-Carbon/

   4. Execute karaf

      cd ../distribution-karaf-0.6.0-Carbon/
      ./karaf

   5. In another console start demo:

      ./run_demo.sh <location_of_fortigate_qcow2_vm>

   6. To check traffic flow run:

      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null 192.168.60.10 "sudo ip netns exec app wget -t1 http://192.168.2.2/"


This will download Ubuntu trusty x86_64 cloud image and install all the necessary packages into host and VMs, so please make sure to export http_proxy and http_proxy environment variables



