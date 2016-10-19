#!/bin/sh
#
# Copyright 2016 (C) NetApp, Inc.
# Author: Ben Swartzlander <ben@swartzlander.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.


VERSION=2016.02
FILENAME=buildroot-${VERSION}.tar.bz2

# Download buildroot if we don't have it already
if [ ! -f download/$FILENAME ]
then
	wget -P download http://buildroot.org/downloads/$FILENAME
fi

# Untar buildroot if it's not already there
if [ ! -d buildroot ]
then
	mkdir buildroot
	tar -C buildroot -xf download/$FILENAME --strip 1
fi

# Apply patches to buildroot if we haven't done so before
PATCH_FLAG_FILE=buildroot/.manila-patches-applied
if [ ! -f $PATCH_FLAG_FILE ]
then
	( cd buildroot ; QUILT_PATCHES=../patches quilt push -a )
	touch $PATCH_FLAG_FILE
fi

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
done

cd ..

# Do the builds
for IMAGE in $BUILD_IMAGES
do
	./make-bootable-disk.sh$ IMAGE
done
