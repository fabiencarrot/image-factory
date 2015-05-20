#!/bin/sh

BASENAME="bundle-trusty-lamp"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"
CW_BUNDLE="LAMP"


# Ubuntu Trusty
SRC_IMG="cc2e31fc-c24d-4905-bb45-1d57794a4f3c"

packer build -var "source_image=$SRC_IMG" -var "image_name=$IMG_NAME" ../apt-bootstrap.packer.json

IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

glance image-update --property cw_bundle=$CW_BUNDLE --property cw_os=Ubuntu --property cw_origin=Cloudwatt --property hw_rng_model=virtio --min-disk 10 --purge-props $IMG_ID

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"

echo "======= Cleaning unassociated floating ips"

for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id
done

echo "======= Cleaning too old images"

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " |cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs glance image-delete

glance image-show $IMG_ID

if [ ! -d "target" ]; then
    mkdir target
fi

sed "s/\\\$IMAGE\\\$/$IMG_ID/g" heat/bundle-trusty-lamp.heat.yml > target/bundle-trusty-lamp.heat.yml
