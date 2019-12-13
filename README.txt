# openstack
cloud-init

Instead of manually creating a VM, logging in to it and executing a few commands to set it up, you can automate all these steps. The creation of the VM and the stuff you do when it is up can all be scripted. You can use a programming language like Python to do this, but simple Bash scripts also work just as well.

cloud-init is a piece of software created to help with initializing virtual machines on multiple different cloud software platforms. It is a collection of Python scripts that run on a VM's first boot.

It understands and talks to different data providers like Amazons or the Openstack metadata service.

It uses that information to, for example, set a root password, grow the root filesystem, setup an SSH key, do a callback to an URL when a VM is finished booting or execute commands at boot. All those things and many more are provided by so called cloud-init modules. Therefor it can be extended easily.

The metadata provided by the cloud provided can contain things like the VM's name, its IP addres(es), a root password or an SSH key. You can also provide your own metadata using the so called user_data.

cloud-init has a nifty feature that allows us to place a script in the user_data which it will execute at the end of the first boot of the machine. It can be a bash script, or any other script as long as it starts with #!.

This tutorial was tested with cloud-init versions 0.7.4 up to 0.7.7. The /etc/cloud/cloud.cfg config file needs the following enabled:

cloud_final_modules:
  - scripts-user

Providing user_data to a new VM in Openstack

To provide the user_data script to a new VM you need to place your user_data script in a file, in this example user_data.file. See below for an example script

Make sure you have the Openstack Command Line Tools installed. For convinience, also create a computerc file which holds your credentials and source it in your shell.

The parameter to supply the user data is --user-data $filename. To boot up a small Ubuntu machine at CloudVPS with our user_data file we can use this command:

nova boot --image "CloudVPS Ubuntu 14.04"  --key-name $ssh_key --flavor "Standard 1" --availability-zone NL1 --user-data user_data.file "Example VPS 1"

If you have the console of the machine open (nova get-vnc-console $UUID novnc) then you should see your script executed at the end of the cloud-init run at boot.
Example user_data cloud-init script

This is an example bash script you can push via the user_data. It gives you a generic idea of what can be done. You could install and setup your configuration management framework like Puppet or Chef, or just use plain commands. This example uses Ansible to deploy the imaginary Example App for your company at first boot:

#!/bin/bash
# Example script to run at first boot via Openstack
# using the user_data and cloud-init.
# This example installs Ansible and deploys your 
# org's example App.

echo "userdata running on hostname: $(uname -n)"
echo "Using pip to install Ansible"
pip2 install --upgrade ansible 2>&1

echo "Cloning repo with example code"
git clone https://gitlab.mycompany.org/ansible/example-app.git /tmp/app

pushd /tmp/app
ansible-playbook ./our-app.yml
popd
exit 0

You can also use Python, Ruby or any of your favorite language. As long as the user_data starts with #! cloud-init will see it as a script and not as specific cloud-init modules. You do need to make sure that your base image has the interpreter installed (Python, Ruby etc.) or bootstrap that via the script.

Here is another script that installs Wordpress on CentOS, including nginx, php- fpm and mysql:

#!/bin/bash
# Example script to run at first boot via Openstack using the user_data and cloud-init. This example installs Wordpress, nginx, MySQL and PHP-FPM.
# Author: Remy van Elst, https://raymii.org; License: GNU GPLv3

printf "\033c" #clear screen
VERSION="$(grep -Eo "[0-9]\.[0-9]" /etc/redhat-release | cut -d . -f 1)"

echo "Installing EPEL"
rpm -Uvh http://cdn.duplicity.so/utils/epel-release-${VERSION}.noarch.rpm 2>&1

echo "Installing Ansible and Git"
yum -y install ansible git gmp 2>&1

echo "Cloning repo with Wordpress Playbook"
git clone https://github.com/RaymiiOrg/ansible-examples.git /tmp/app 2>&1

echo "Creating Ansible inventory file"
echo -e "[wordpress-server]\n127.0.0.1" > /tmp/app/wordpress-nginx/inventory

echo "Starting playbook"
cd /tmp/app/wordpress-nginx
ansible-playbook -i inventory ./site.yml 2>&1

exit 0

The repository was forked from Ansible's example repo and changed so that the site.yml playbook includes the connection: local line. That way we don't use SSH to run the playbook. It also randomly generates the database password instead of using a variable.
Re-execute or debugging

The script only runs at first boot of the machine via cloud-init. If you execute the cloud-init command again it will not execute the script because it already did it. Testing and debugging the script can be quite intensive if you need to boot up a machine every time.

We can however fool cloud-init by letting it think the machine did a fresh first boot. We need to remove the following two files:

/var/lib/cloud/instances/$UUID/boot-finished
/var/lib/cloud/instances/$UUID/sem/config_scripts_user

Replace $UUID by your instance's UUID.

Execute the following command to run the cloud-init final module again:

cloud-init modules --mode final

The final module will execute our user_data script again. Before every new test run you need to remove the two files listed above.

Keep in mind as well that if you for example touch a file and run the script again, the file will still be there. Changes are persistent, build your code idempotent so that it handles that.

If you've by accident deleted to much cloud-init data you can re-initialize it with the following command:

cloud-init init

Command Line script to create VM's

Here is an example script you can use to create an amount of VM's using the command line. It will wait until the VM is active before creating the next one, and it passes through a user_data file. You can use this, for example, to easily start up 20 servers and set them up as Apache webservers to scale up when your site gets a lot of traffic and needs to scale up.

You do need to place a credentials file named computerc in your home folder.

#!/bin/bash
KEY="SSH Key Name"
BOOTIMG="IMAGE UUID"
ZONE="NL1"
FLAVOR="Standard 1"

source ~/computerc 

for RUN in {1..20}; do
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

done
