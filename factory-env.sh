#!/bin/sh

# This file should be source to make the scripts take all values specific to a factory instance.

# ID of validated base system images
export BASE_IMG_UBUNTU_TRUSTY="d1f0726c-1186-4269-948e-72f6493d93c2"

# Network ID to use for VM deployment during build
export FACTORY_NETWORK="17decd89-56a2-4729-8bd6-453ebaa51860"
export FACTORY_SECURITY_GROUP="FACTORY-SG-ZH6NLTYBM7FY"

# Floating IP pool to use
export FACTORY_FLOATING_IP_POOL="6ea98324-0f14-49f6-97c0-885d1b8dc517"