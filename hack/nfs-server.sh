#!/usr/bin/env bash

[ ! -f .env ] || export $(grep -v '^#' .env | xargs)

sudo apt update
sudo apt install -y nfs-kernel-server

# Prepare a share directories in NFS Server
sudo mkdir -p ${NFS_PATH}
sudo mkdir -p ${NFS_PATH}/data ${NFS_PATH}/models ${NFS_PATH}/logs

sudo chown nobody:nogroup ${NFS_PATH}
sudo chmod g+rwxs ${NFS_PATH}

echo "/mnt/nfs  ${NODE_SUBNET}(rw,sync,no_subtree_check,insecure,no_root_squash,no_all_squash)" | sudo tee -a /etc/exports

sudo exportfs -rav
sudo systemctl restart nfs-kernel-server
