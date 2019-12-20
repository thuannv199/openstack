#!/usr/bin/bash
# creates a new OpenStack project/user
# optionally creates a generic network, subnet, router and
# sets the default GW so users can immediately start using things.
# also sets up security group rules for SSH/ICMP
# usage :: run from openstack controller
# usage :: source admin-openrc
# usage :: ./create-user.sh

# this should be your Neutron external network
EXTERNAL_NET_ID="6f13cfe8-9929-47ef-b140-9955edb18fd2"
# this should be internal self server network
INTERNAL_NET_NAME="internal"
# selfservice subnet
INTERNAL_SUBNET_NAME="internal"
# ip address of your controller
CONTROLLER_PUB_IP="10.0.0.10"
# generic password for new users
USER_PASSWORD="stack"
USER_DOMAIN="@atvn.com.vn"
# users generic internal network
user_net_cidr='11.0'
#gateway
user_net_gw='11.0'
# where tokens are stored
token_location="/root/keystonerc.d"
# where admin-level token is located
admin_token='/root/admin-openrc'
# random string for project network,subnet,router
# this is so multiple networks created inside same project
# have a unique name
randstring=`date | md5sum | cut -c1-5`
# change this to https if you're using SSL endpoints
endpoint_proto='http'
# nameserver for projects to use
dns_nameserver=8.8.8.8
# default quotas
df_cores=4 # vCPU
df_instances=2 # number of instances
df_ram=16384 # MB of RAM
df_floating_ips=2 # number of floating ip
df_networks=2 # number of network
df_subnets=2 # number of subnet 
df_ports=10 # number of port
df_routers=2 # number of router

get_id() {
  #echo '"$@" | awk '/id / {print $4}''
  echo `"$@" | grep " id" | awk '{print $4}'`
}

create_project_user() {
project_id=$(get_id openstack project show ${project_name})
  if [[ -z $project_id ]]
  then
        project_id=$(get_id openstack project create --domain default --enable ${project_name})
  fi

  user_id=$(get_id openstack user create --project ${project_name} --project-domain default --password $USER_PASSWORD --email ${user_name}${USER_DOMAIN} $user_name)
  #member_id=$(get_id openstack role show _member_)
  openstack role add --project $project_id --user $user_id user
  openstack quota set --cores $df_cores --instances $df_instances \
					--ram $df_ram --floating-ips $df_floating_ips \
					--networks $df_networks --subnets $df_subnets \
					--ports $df_ports --routers $df_ports $project_id

cat > $token_location/keystonerc_${user_name} <<EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=$project_name
export OS_USERNAME=$user_name
export OS_PASSWORD=$USER_PASSWORD
export OS_AUTH_URL="${endpoint_proto}://${CONTROLLER_PUB_IP}:5000/v3"
export OS_AUTH_STRATEGY=keystone
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1="[\u@\h \W(keystone_$user_name)]$ "
EOF
}

create_project_network() {
  project_network_name=$project_name-$INTERNAL_NET_NAME
  project_router_name=default-router-$project_name-$randstring
  project_subnet_name=$project_name-$INTERNAL_SUBNET_NAME
  project_gateway_ip=$user_net_gw
  project_created_id=$(openstack project show $project_name | grep " id" | awk '{print $4}')

# source newly created keystonerc so we create network as that user
source $token_location/keystonerc_$user_name

# create new network, subnet and router
openstack router create  $project_router_name
openstack router set $project_router_name --external-gateway $EXTERNAL_NET_ID
router_external_ip=$(openstack router show $project_router_name | grep external_gateway_info | awk '{print $12}' | cut -c2-14) #get gateway ip address
project_subnet_net=$user_net_cidr.$(echo $router_external_ip | cut -c11-14).0 # generate a new cidr 
openstack network create $project_network_name
openstack subnet create --network $project_network_name --subnet-range $project_subnet_net/24 --dns-nameserver $dns_nameserver $project_subnet_name

# obtain newly created router, network and subnet id
project_router_id=$(openstack router list | grep $project_router_name | awk '{print $2}')
project_subnet_id=$(openstack subnet list | grep $project_subnet_name | awk '{print $2}')
project_network_id=$(openstack network list | grep $project_network_name | awk '{print $2}')

# associate router and add interface to the router
openstack router add subnet $project_router_id $project_subnet_id
ip route add $project_subnet_id/24 via $router_external_ip

}

create_project_securitygroup() {      
		openstack security group rule create   \
                --protocol icmp              \
                --ingress          \
                --prefix 0.0.0.0/0 \
                default
        openstack security group rule create   \
                --protocol tcp               \
                --dst-port 22          \
                --ingress          \
                --prefix 0.0.0.0/0 \
                default
}

# parse input and execute functions
cat <<EndofMessage
#####################################################
#           OpenStack Account Creator 2019          #
#                                                   #
#####################################################
EndofMessage

# source admin token again
source $admin_token

echo -en "Enter project name (defaults to username): "
read project_name

echo -en "Enter User name: "
read user_name

echo -en "Create Generic Network? Y/N: "
read generic_net

# sanity check network input
case $generic_net in
        y|Y) create_network="1"
                ;;
        n|N) create_network="0"
                ;;
        *)   echo "::Error:: Answer Y/N for network creation"
             exit 1
esac

if [ -z $generic_net ];
then
        echo "::ERROR:: Network selection empty, choose Y/N"
        exit 1
fi

# call function to create project and user
if [ ! -z $project_name ] && [ ! -z $user_name ];
then
        echo "Creating user..."
		sleep 2
		create_project_user $project_name $user_name $USER_PASSWORD >/dev/null 2>&1
else
        echo "::ERROR:: either project or user is empty"
        exit 1
fi

# call function to create generic network
if [ $create_network == "1" ];
then
		echo "Creating network..."
		sleep 2
		create_project_network >/dev/null 2>&1
		echo "Setting security group..."
		sleep 2
        create_project_securitygroup >/dev/null 2>&1
fi

# summarize what we did
# source admin again to obtain project id
source $admin_token
echo "Finalizing configuration..."
sleep 5
cat <<EndofMessage
####################################
#    OpenStack Account Summary     #
====================================
Username:     $user_name
project:       $project_name
project ID:    $(openstack project show $project_name 2>/dev/null | grep " id" | awk '{print $4}')
Network Name: $project_network_name
Network ID:   $project_network_id
Loggin url: http://http://172.33.47.17/horizon/auth/login/
Default password: "stack"
Help: thuannv@atvn.com.vn / 082 751 91 96
====================================
EndofMessage
