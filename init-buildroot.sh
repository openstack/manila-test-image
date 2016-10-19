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
