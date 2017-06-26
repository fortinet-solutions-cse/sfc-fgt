#!/bin/bash

source ./env.sh

virsh destroy ${CLASSIFIER1_NAME}
virsh undefine ${CLASSIFIER1_NAME}
rm -f ${CLASSIFIER1_NAME}.img
rm -f ${CLASSIFIER1_NAME}-cidata.iso

virsh destroy ${CLASSIFIER2_NAME}
virsh undefine ${CLASSIFIER2_NAME}
rm -f ${CLASSIFIER2_NAME}.img
rm -f ${CLASSIFIER2_NAME}-cidata.iso

virsh destroy ${SFF1_NAME}
virsh undefine ${SFF1_NAME}
rm -f ${SFF1_NAME}.img
rm -f ${SFF1_NAME}-cidata.iso

virsh destroy ${SFF2_NAME}
virsh undefine ${SFF2_NAME}
rm -f ${SFF2_NAME}.img
rm -f ${SFF2_NAME}-cidata.iso

virsh destroy ${SF1_NAME}
virsh undefine ${SF1_NAME}
rm -f ${SF1_NAME}.img
rm -f ${SF1_NAME}-cidata.iso

virsh destroy ${SF2_NAME}
virsh undefine ${SF2_NAME}
rm -f ${SF2_NAME}.img
rm -f ${SF2_NAME}-cidata.iso

virsh destroy ${SF2_PROXY_NAME}
virsh undefine ${SF2_PROXY_NAME}
rm -f ${SF2_PROXY_NAME}.img
rm -f ${SF2_PROXY_NAME}-cidata.iso

rm -f fgt-logs.qcow2
rm -f fortios.qcow2
rm -f proxy.py*
rm -rf cfg-drv-fgt

rm -f user-data
rm -f meta-data
rm -f virbr1
rm -f virbr2
rm -f virbr3

virsh net-destroy virbr1
virsh net-destroy virbr2
virsh net-destroy virbr3
