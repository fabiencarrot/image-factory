#!/bin/sh

BASENAME="bundle-trusty-pgsql"
TENANT_ID="772be1ffb32e42a28ac8e0205c0b0b90"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
CW_BUNDLE="POSTGRESQL"

# Ubuntu
SRC_IMG="cc2e31fc-c24d-4905-bb45-1d57794a4f3c"

packer build -var "source_image=$SRC_IMG" -var "image_name=$IMG_NAME" ../apt-bootstrap.packer.json

IMG_ID="$(glance image-list --owner $TENANT_ID --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"

if [ "$IMG_ID" ]; then
    echo "Failed to get image id"
    exit 1
fi

glance image-update \
       --property cw_bundle=$CW_BUNDLE \
       --property cw_os=Ubuntu \
       --property cw_origin=Cloudwatt \
       --property hw_rng_model=virtio \
       --min-disk 10 \
       --purge-props \
       $IMG_ID

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"

echo "======= Cleaning unassociated floating ips"

for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id
done

echo "======= Cleaning too old images"

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " | cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs -r glance image-delete

glance image-show $IMG_ID

rm -rf target
mkdir target

sed "s/\\\$IMAGE\\\$/$IMG_ID/g" heat/$BASENAME.heat.yml > target/$BASENAME.heat.yml
