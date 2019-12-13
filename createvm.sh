#!/bin/bash
KEY="SSH Key Name"
BOOTIMG="IMAGE UUID"
ZONE="NL1"
FLAVOR="Standard 1"

source ~/computerc 
echo "Creating VM ${RUN}""
VMUUID=$(nova boot \
     --image "${BOOTIMG}" \
     --flavor "${FLAVOR}" \
     --availability-zone "${ZONE}" \
     --nic net-id=00000000-0000-0000-0000-000000000000 \
     --key-name "${KEY}" \
     --user-data user_data.file \
     "VPS-${RUN}-${ZONE}" | awk '/id/ {print $4}' | head -n 1);

until [[ "$(nova show ${VMUUID} | awk '/status/ {print $4}')" == "ACTIVE" ]]; do
        :
done
echo "VM ${RUN} (${VMUUID}) is active."