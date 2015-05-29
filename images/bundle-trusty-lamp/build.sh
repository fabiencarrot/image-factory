#!/bin/sh

BASENAME="bundle-trusty-lamp"
CW_BUNDLE="LAMP"

if [ ! "$OS_TENANT_ID" ]; then
    echo "OS_TENANT_ID env variable is mandatory"
    exit 1
fi

SELF_PATH=`dirname "$0"`
FACTORY_ENV="$SELF_PATH/../../factory-env.sh"

. $FACTORY_ENV

if [ "$?" -ne "0" ]; then
    echo "Could not source factory environment: $FACTORY_ENV"
    exit 1
fi

PACKER_FILE="../bundle-bootstrap.packer.json"
BUILDMARK="$(date +%Y-%m-%d-%H%M)"
IMG_NAME="$BASENAME-$BUILDMARK"
TMP_IMG_NAME="$IMG_NAME-tmp"
SRC_IMG="$BASE_IMG_UBUNTU_TRUSTY"

echo "floating : $FACTORY_FLOATING_IP_POOL"

echo "======= Packer provisionning..."
packer build -var "source_image=$SRC_IMG" -var "image_name=$IMG_NAME" $PACKER_FILE

echo "======= Glance upload..."
IMG_ID="$(glance image-list --owner $OS_TENANT_ID --is-public False | grep $IMG_NAME | tr "|" " " | tr -s " " | cut -d " " -f2)"
glance image-update \
    --property cw_bundle=$CW_BUNDLE \
    --property cw_os=Ubuntu \
    --property cw_origin=Cloudwatt \
    --property hw_rng_model=virtio \
    --min-disk 10 \
    --purge-props $IMG_ID


echo "======= Cleaning unassociated floating ips"

FREE_FLOATING_IP="$(neutron floatingip-list | grep -v "+" | grep -v "id" | tr -d " " | grep -v -E "^\|.+\|.+\|.+\|.+\|$" | cut -d "|" -f 2)"

for floating_id in $FREE_FLOATING_IP; do
    neutron floatingip-delete $floating_id
done

echo "======= Cleaning too old images"

glance image-list | grep $BASENAME | tr "|" " " | tr -s " " | cut -d " " -f 3 | sort -r | awk 'NR>5' | xargs -r glance image-delete


echo "======= Generating Heat template"

if [ ! -d "$SELF_PATH/target" ]; then
    mkdir $SELF_PATH/target
fi
sed "s/\\\$IMAGE\\\$/$IMG_ID/g" $SELF_PATH/heat/bundle-trusty-lamp.heat.yml > $SELF_PATH/target/bundle-trusty-lamp.heat.yml

echo "======= Image detail"

glance image-show $IMG_ID