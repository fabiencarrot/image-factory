#!/bin/sh

BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BUILDMARK-debian-jessie"
IMG=debian-8.0.0-openstack-amd64.qcow2
IMG_URL=http://cdimage.debian.org/cdimage/openstack/current/$IMG

TMP_DIR=debian-jessie-guest

if [ ! -f "$IMG" ]; then
    wget $IMG_URL
fi

if [ ! -d "$TMP_DIR" ]; then
    mkdir $TMP_DIR
fi

guestmount -a $IMG -i $TMP_DIR

sed -i "s#name: debian#name: cloud#" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#gecos: Debian#gecos: Cloud user#" $TMP_DIR/etc/cloud/cloud.cfg
sed -i "s#debian#cloud#" $TMP_DIR/etc/sudoers.d/debian-cloud-init
sed -i "#ed25519#d" $TMP_DIR/etc/ssh/sshd_config
sed -i "/gecos/a \ \ \ \ \ shell: \/bin\/bash" $TMP_DIR/etc/cloud/cloud.cfg

guestunmount $TMP_DIR

glance image-create \
       --file $IMG \
       --disk-format qcow2 \
       --container-format bare \
       --name "$IMG_NAME-tmp"

TMP_IMG_ID="$(glance image-list --owner 772be1ffb32e42a28ac8e0205c0b0b90 --is-public False | grep $IMG_NAME-tmp | tr "|" " " | tr -s " " | cut -d " " -f2)"

packer build -var "source_image=$TMP_IMG_ID" -var "image_name=$IMG_NAME" packer/jessie.packer.json

glance image-delete $IMG_NAME-tmp

IMG_ID="$(glance image-list --owner 772be1ffb32e42a28ac8e0205c0b0b90 --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

glance image-update --property cw_os=Debian --property cw_origin=Cloudwatt --property hw_rng_model=virtio --min-disk 10 --purge-props $IMG_ID

glance image-show $IMG_ID
