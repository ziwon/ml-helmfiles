#!/usr/bin/env bash

[ ! -f .env ] || export $(grep -v '^#' .env | xargs)

sudo apt update
sudo apt install -y nfs-kernel-server

sudo mkdir -p ${NFS_EXPORT_PATH}
sudo chown nobody:nogroup ${NFS_EXPORT_PATH}
sudo chmod g+rwxs ${NFS_EXPORT_PATH}

echo "/mnt/nfs  ${NODE_SUBNET}(rw,sync,no_subtree_check,insecure,no_root_squash,no_all_squash)" | sudo tee -a /etc/exports

sudo exportfs -rav
sudo systemctl restart nfs-kernel-server
