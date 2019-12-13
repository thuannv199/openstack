#!/bin/bash
###Script environment
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
#Input user
echo "Enter your project name: "
read user_project
export OS_PROJECT_NAME=$user_project
echo "Enter your user name (computer user): "
read user_name
export OS_USERNAME=$user_name
prompt="password:"
while IFS= read -p "$prompt" -r -s -n 1 char
do
    if [[ $char == $'\0' ]]
    then
         break
    fi
    prompt='*'
    password+="$char"
done
export OS_PASSWORD=$char

# KEY="SSH Key Name"
BOOTIMG="9b2cb0e3-0394-4780-8caf-90096af8e523"  #image uuid
ZONE="nova"
FLAVOR="m1.small"
#Create instance
source ~/computerc #initiate user environment
echo "Creating VM ${RUN}"
VMUUID=$(openstack server create \
     --image "${BOOTIMG}" \
     --flavor "${FLAVOR}" \
     --availability-zone "${ZONE}" \
     --nic net-id=30061cb1-6d10-4b79-ac9b-5047330354c4 \
     --user-data user_data.file \
     "VPS-${RUN}-${ZONE}" | awk '/id/ {print $4}' | head -n 1);
until [[ "$(openstack server show ${VMUUID} | awk '/status/ {print $4}')" == "ACTIVE" ]]; do
echo "VM ${RUN} (${VMUUID}) is active."
done
#Ouput
CONSOLE_LINK=$(openstack console url show --spice ${VMUUID});
echo "Console link in: ${CONSOLE_LINK}"
echo "IP address: $(openstack server show ${VMUUID} | awk '/addresses/ {print $4}')"
