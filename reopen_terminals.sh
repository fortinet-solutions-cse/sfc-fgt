#!/usr/bin/env bash

. env.sh

xterm -geometry 110x25+650+255 -e 'sshpass -p karaf ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p 8101 -l karaf 127.0.0.1' &

xterm -geometry 55x30+20+20 -bg darkblue -title "SF1 Log" -e ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF1_IP} "tail -F sf1_log.log" &
xterm -geometry 55x30+370+20 -bg darkblue -title "SF2PROXY Log" -e ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF2_PROXY_IP} "tail -F proxy.log" &
xterm -geometry 55x30+720+20 -bg darkblue -title "SF3PROXY Log" -e ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF3_PROXY_IP} "tail -F proxy.log" &
xterm -geometry 55x30+1070+20 -bg darkblue -title "SF4PROXY Log" -e ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${SF4_PROXY_IP} "tail -F proxy.log" &

xterm -geometry 70x14+1450+24 -fg yellow -e watch virsh net-list --all &

xterm -geometry 70x16+1450+250 -fg yellow -e watch virsh list --all &

xterm -geometry 80x30+20+540 -bg grey -fg black -title "User 1 shell" -e ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app bash" &
xterm -geometry 80x30+525+540 -bg grey -fg black -title "User 2 shell" -e ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app2 bash" &
xterm -geometry 80x30+1030+540 -bg grey -fg black -title "User 3 shell" -e ssh -t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${CLASSIFIER1_IP} "sudo ip netns exec app3 bash" &
xterm -geometry 60x31+1535+505 -bg lightgreen -fg black -title "Schema" -e 'head -n57 ./run_demo_mwc.sh;bash' &
