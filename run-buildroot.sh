#!/bin/sh -xe
#
# Copyright 2016 (C) NetApp, Inc.
# Author: Ben Swartzlander <ben@swartzlander.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

./init-buildroot.sh

# Grab JSON.sh for json parsing
JSON_VERS=e05e69a0debdba68125a33ac786726cb860b2e7b
GITHUB_RAW=https://raw.githubusercontent.com
JSON_URL=$GITHUB_RAW/dominictarr/JSON.sh/$JSON_VERS/JSON.sh
JSON_SH=download/JSON.sh
if [ ! -x download/JSON.sh ] ; then
    curl -s $JSON_URL > $JSON_SH
    chmod +x $JSON_SH
fi

# Create the filesystem overlays
if [ ! -d overlay-client ] ; then
    mkdir overlay-client
    cp -a common-files/* overlay-client
    cp $JSON_SH overlay-client/usr/bin
fi

# Copy the config files where they need to go (temporarily)
cp conf/buildroot-client.config buildroot/configs/manila_client_defconfig

cd buildroot
BUILD_IMAGES="client"

# Allow building as root (common in CI/containers)
export FORCE_UNSAFE_CONFIGURE=1

# Setup the build directories with their configs
for IMAGE in $BUILD_IMAGES ; do
    make O=../output-${IMAGE} manila_${IMAGE}_defconfig
done

# Remove the temporary configs
rm configs/manila_*_defconfig

# Do the builds
for IMAGE in $BUILD_IMAGES ; do
    make O=../output-${IMAGE} all
    ( cd .. ; ./make-bootable-disk.sh $IMAGE )
done
