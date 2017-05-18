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
1. Install virtualbox & vagrant
2. Start ODL SFC in host machine and install necessary features

   feature:install odl-sfc-scf-openflow odl-sfc-openflow-renderer odl-sfc-ui


   Notice: please do stop, clean up, then restart ODL SFC when you run this demo in order that demo can run successfully.

   opendaylight-user@root>shutdown -f
   opendaylight-user@root>
   $ rm -rf data snapshots journal instances
   $ ./bin/karaf

3. Run demo

  This will download Ubuntu trusty x86_64 vagrant image and install all the necessary packages into host and vagrant VMs, so please make sure to export http_proxy and http_proxy environment variables if you have proxy behind your network before run demo script, demo script will inject these proxy settings to vagrant VMS.

     $ ./run_demo.sh

