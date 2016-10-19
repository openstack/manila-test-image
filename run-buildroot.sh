#!/bin/sh
#
# Copyright 2016 (C) NetApp, Inc.
# Author: Ben Swartzlander <ben@swartzlander.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

./init-buildroot.sh

# Create the filesystem overlays
if [ ! -d overlay-client ]
then
	mkdir overlay-client
	cp -a common-files/* overlay-client
fi
if [ ! -d overlay-server ]
then
	mkdir overlay-server
	cp -a common-files/* overlay-server
	cp -a server-files/* overlay-server
fi

# Copy the config files where they need to go (temporarily)
cp conf/buildroot-client.config buildroot/configs/manila_client_defconfig
cp conf/buildroot-server.config buildroot/configs/manila_server_defconfig
cp conf/buildroot-debug.config buildroot/configs/manila_debug_defconfig

cd buildroot
BUILD_IMAGES="client server"

# Setup the build directories with their configs
for IMAGE in $BUILD_IMAGES
do
	make O=../output-${IMAGE} manila_${IMAGE}_defconfig
done

# Remove the temporary configs
rm configs/manila_*_defconfig

# Do the builds
for IMAGE in $BUILD_IMAGES
do
	make O=../output-${IMAGE} all
	( cd .. ; ./make-bootable-disk.sh $IMAGE )
done

