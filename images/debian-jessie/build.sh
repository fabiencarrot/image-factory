#!/bin/sh

BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BUILDMARK-debian-jessie"
IMG=debian-8.0.0-openstack-amd64.qcow2
IMG_URL=http://cdimage.debian.org/cdimage/openstack/current/$IMG

TMP_DIR=debian-jessie-guest

wget $IMG_URL

if [ ! -d "$TMP_DIR" ]; then
    sudo mkdir $TMP_DIR
fi

guestmount -a $IMG -i $TMP_DIR

sed -i "s#name: debian#name: cloud#" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#gecos: Debian#gecos: Cloud user#" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#debian#cloud#" $TMP_DIR/etc/sudoers.d/debian-cloud-init
sed -i "#ed25519#d" $TMP_DIR/etc/ssh/sshd_config

sudo sed -i "/gecos/a \ \ \ \ \ shell: \/bin\/bash" $TMP_DIR/etc/cloud/cloud.cfg
sudo guestunmount $TMP_DIR

glance image-create \
       --file $IMG \
       --disk-format qcow2 \
       --container-format bare \
       --name "$IMG_NAME"

echo "Image built: $(glance image-list --owner 772be1ffb32e42a28ac8e0205c0b0b90 --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f3,2)"
