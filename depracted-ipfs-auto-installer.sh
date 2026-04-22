#!/bin/bash
echo ''
# Kubo doesn't require sudo/root privileges, so it's best to run all ipfs commands as a regular user!
read -p 'Confirm your current username: ' user_name
echo ''
# If you are running a Kubo node in a data center, you should initialize IPFS with the server profile. 
# Doing so will prevent IPFS from creating data center-internal traffic trying to discover local nodes
read -p 'Will this node be run in a data center? y/n: ' server_profile
echo ''
# You might want to skip this one if allowing people to access files through your gateway makes you nervous##
read -p 'Enable as a public gateway? y/n: ' public_access
echo ''
# If your instance gets restarted, IPFS will start automatically.
read -p 'Starts IPFS automatically at boot time? y/n: ' enable_service
echo ''
# A soft upper limit for the size of the ipfs repository's datastore. 
read -p 'Set the max storage capacity in GB: ' max_storage

cd /home/${user_name}

echo ''
echo '          ╔══════════════════════════════════════════════════════════════╗'
echo '          ║                      Dowloading IPFS                         ║'
echo '          ╚══════════════════════════════════════════════════════════════╝'
echo ''

wget -qO- "https://dist.ipfs.tech/kubo/versions" > versions.txt
versions="versions.txt"
latest=$(grep -v 'rc' versions.txt | tail -n 1)
wget "https://dist.ipfs.tech/kubo/${latest}/kubo_${latest}_linux-amd64.tar.gz"
rm versions.txt

echo '          ╔══════════════════════════════════════════════════════════════╗'
echo '          ║                      Installing IPFS                         ║'
echo '          ╚══════════════════════════════════════════════════════════════╝'
echo ''

tar -xvzf "kubo_${latest}_linux-amd64.tar.gz"
rm "kubo_${latest}_linux-amd64.tar.gz"
cd kubo 
sudo bash install.sh
cd .. 
rm -rf kubo
ipfs --version 

# echo 'export IPFS_PATH=/data/ipfs' >>~/.bashrc
# source ~/.bashrc
# sudo mkdir -p $IPFS_PATH
# sudo chown $user:$user $IPFS_PATH

echo ''
echo '          ╔══════════════════════════════════════════════════════════════╗'
echo '          ║                   !Initiating repository!                    ║'
echo '          ╚══════════════════════════════════════════════════════════════╝'
echo ''

if [ "$server_profile" = "y" ]; then
    sudo -u ${user_name} ipfs init --profile server
    echo ''
    echo '          ╔══════════════════════════════════════════════════════════════╗'
    echo '          ║      Internal data center traffic will not be generated.     ║'
    echo '          ╚══════════════════════════════════════════════════════════════╝'
    echo ''
else
    sudo -u ${user_name} ipfs init
fi

sudo -u ${user_name} ipfs config Datastore.StorageMax "${max_storage}GB"
sudo -u ${user_name} ipfs id | head -n 3 | tail -n 2 > IPFS_identity.txt

if [ "$public_access" = "y" ]; then
   ipfs config Addresses.Gateway /ip4/0.0.0.0/tcp/8080
    echo ''
    echo '          ╔══════════════════════════════════════════════════════════════╗'
    echo '          ║                !Public gateway :8080 enabled!                ║'
    echo '          ╚══════════════════════════════════════════════════════════════╝'
    echo ''
else
    ipfs config Addresses.Gateway /ip4/127.0.0.1/tcp/8080
    echo ''
    echo '          ╔══════════════════════════════════════════════════════════════╗'
    echo '          ║                   !Public gateway disabled!                  ║'
    echo '          ╚══════════════════════════════════════════════════════════════╝'
    echo ''
fi

echo ''
echo '          ╔══════════════════════════════════════════════════════════════╗'
echo '          ║                Creating ipfs.service entry                   ║'
echo '          ╚══════════════════════════════════════════════════════════════╝'
echo ''

# =======================================================
sudo bash -c 'cat >/etc/systemd/system/ipfs.service <<EOL
[Unit]
Description=IPFS Service
After=network.target
Before=nextcloud-web.service
[Service]
ExecStart=/usr/local/bin/ipfs daemon --enable-gc
ExecReload=/usr/local/bin/ipfs daemon --enable-gc
Restart=on-failure
User='"$user_name"'
Group='"$user_name"'
[Install]
WantedBy=default.target
EOL'
# =======================================================

sudo systemctl daemon-reload
if [ "$enable_service" = "y" ]; then
    sudo systemctl enable ipfs.service
else
    echo ''
    echo '          ╔══════════════════════════════════════════════════════════════╗'
    echo '          ║   Remember "sudo systemctl start ipfs.service" after reboot  ║'
    echo '          ╚══════════════════════════════════════════════════════════════╝'
    echo ''
fi
sudo systemctl start ipfs.service 
sudo systemctl status ipfs.service 

#echo ''
#echo '          ╔══════════════════════════════════════════════════════════════╗'
#echo '          ║                     Installing nginx                         ║'
#echo '          ╚══════════════════════════════════════════════════════════════╝'
#echo ''

#sudo apt install nginx -y
#echo ''
#echo '          ╔══════════════════════════════════════════════════════════════╗'
#echo '          ║                  Checking nginx.service                      ║'
#echo '          ╚══════════════════════════════════════════════════════════════╝'
#echo ''
#sudo systemctl status nginx

#sudo nginx -s reload

# ipfs config Addresses.Swarm '["/ip4/0.0.0.0/tcp/4001", "/ip4/0.0.0.0/tcp/8081/ws", "/ip6/::/tcp/4001"]' --json
# try to ignore the next line
# ipfs config --bool Swarm.EnableRelayHop false

sudo systemctl restart ipfs.service

echo ''
echo '          ╔══════════════════════════════════════════════════════════════╗'
echo '          ║              All done, restarting ipfs.service               ║'
echo '          ╚══════════════════════════════════════════════════════════════╝'
echo ''
