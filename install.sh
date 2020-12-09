#!/usr/bin/env bash
echo "###################################"
echo "######## set var start ############"
echo "###################################"

# openvpn server ip
opvn_server_ip=0.0.0.0

# openvpn user use "," split multi users
opvn_user=testuser

# ss password
ss_pwd=sspassword

# docker docker_target_dir
docker_target_dir=/var/services_by_docker

echo "###################################"
echo "########## set var end ############"
echo "###################################"



echo "###################################"
echo "######## install docker############"
echo "###################################"

mkdir $docker_target_dir -p

cp -R services_by_docker/* $docker_target_dir

sudo apt-get remove docker docker-engine docker.io containerd runc

sudo apt-get update

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common -y

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io -y

docker network create frontend

echo "#####################################"
echo "######## install docker-compose ############"
echo "#####################################"

docker_compose_path=/usr/local/bin/docker-compose
if [ ! -x $docker_compose_path ]; then
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" -o $docker_compose_path
sudo chmod +x $docker_compose_path
fi

echo "#####################################"
echo "######## docker ss and openvpn ############"
echo "#####################################"


cd $docker_target_dir/openvpn
cat <<eof > .env
OPV_HOST=$opvn_server_ip
OPV_SCHEME=tcp
METHOD=chacha20-ietf-poly1305
PASSWORD=$ss_pwd
eof
mkdir option -p
rm -rf option/*


docker-compose run --rm openvpn bash <<eof
echo "###############################################"
echo "############# docker cmd start ################"
echo "openvpn address: "\$OPV_SCHEME://\$OPV_HOST
ovpn_genconfig -u \$OPV_SCHEME://\$OPV_HOST

touch /etc/openvpn/vars
echo ca_title\n | ovpn_initpki nopass

user_target=/etc/openvpn/opvn_user_options
mkdir $user_target -p

echo "############# generate user ################"
opvn_user_array=(${opvn_user//,/ })
for username in \${opvn_user_array[@]}
do
    echo "generate user: "\$username
    easyrsa build-client-full \$username nopass
    ovpn_getclient \$username > "\$user_target/\$username.ovpn"
done 


echo "############# docker cmd end ################"
echo "###############################################"
eof



docker-compose up -d