#!/bin/bash
 ###Script environment
    OS_PROJECT_DOMAIN_NAME=Default
    OS_USER_DOMAIN_NAME=Default
    OS_AUTH_URL=http://controller:5000/v3
    OS_IDENTITY_API_VERSION=3
    OS_IMAGE_API_VERSION=2
   # OS_PROJECT_NAME=$user_project
   # OS_USERNAME=$user_name
   # OS_PASSWORD=$char
    # KEY="SSH Key Name"
#Input user
OS_PROJECT_NAME=$(read -p "Enter your project name: ")
echo #New line
OS_USERNAME=$(read -p "Enter your user name (computer user): ")
echo #New line
OS_PASSWORD=$(read -p "password:")
echo #New line
#Verify
response=$(read -p "Are you sure? ")
echo    #new line
if [[ $response =~ "y" ]];
then
    BOOTIMG="9b2cb0e3-0394-4780-8caf-90096af8e523"  #image uuid
    ZONE="nova"
    FLAVOR="m1.small"
    #Create instance
    # source ~/computerc #initiate user environment
    echo "Creating VM ..."
    openstack project create --domain default service $OS_PROJECT_NAME
    openstack user create --domain default $OS_USERNAME
    openstack user set --password $OS_PASSWORD $OS_USERNAME
    VMUUID=$(openstack server create \
        --image "${BOOTIMG}" \
         --flavor "${FLAVOR}" \
        --availability-zone "${ZONE}" \
        --nic net-id=30061cb1-6d10-4b79-ac9b-5047330354c4 \
        --user-data user_data.file \
        "VPS-${ZONE}" | awk '/id/ {print $4}' | head -n 1);
    until [[ "$(openstack server show ${VMUUID} | awk '/status/ {print $4}')" == "ACTIVE" ]]; do
    echo "VM (${VMUUID}) is active."
    done
    #Ouput
    CONSOLE_LINK=$(openstack console url show --spice ${VMUUID});
    echo "Console link in: ${CONSOLE_LINK}"
    echo "IP address: $(openstack server show ${VMUUID} | awk '/addresses/ {print $4}')"
fi
