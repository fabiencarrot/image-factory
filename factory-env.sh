#!/bin/sh

# This file should be source to make the scripts take all values specific to a factory instance.

# ID of validated base system images
export BASE_IMG_UBUNTU_TRUSTY="ae3082cb-fac1-46b1-97aa-507aaa8f184f"

# Network ID to use for VM deployment during build

if [ ! "$FACTORY_NETWORK" ]; then
  export FACTORY_NETWORK="17decd89-56a2-4729-8bd6-453ebaa51860"
fi

if [ ! "$FACTORY_SECURITY_GROUP" ]; then
  export FACTORY_SECURITY_GROUP="FACTORY-sg-zh6nltybm7fy"
fi

# Floating IP pool to use
# packer openstack builder does not interpolate var for ip_pool
# so this value should also be put as-is in place in your packer files.
export FACTORY_FLOATING_IP_POOL="6ea98324-0f14-49f6-97c0-885d1b8dc517"
