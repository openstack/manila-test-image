#!/bin/sh
#
# Copyright 2016 (C) NetApp, Inc.
# Author: Ben Swartzlander <ben@swartzlander.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.

DISK_NAME=$1
BR_OUTPUT=output-$1

if [ -z "$DISK_NAME" ]
then
	echo Specify disk name
	exit 2
fi

SIZE=120m
DISK_QCOW=$DISK_NAME.qcow2
TEMP_QCOW=/tmp/temp.qcow2
NBD=/dev/nbd0
PART=${NBD}p1
MOUNT=/mnt/tmp

echo Creating temp qcow2
rm -f $TEMP_QCOW
qemu-img create -f qcow2 $TEMP_QCOW $SIZE

echo Loading NBD module
sudo modprobe nbd max_part=15

echo Creating NBD from qcow2
sudo qemu-nbd -c $NBD -f qcow2 $TEMP_QCOW

echo Writing partition table
sudo parted -s $NBD -- mklabel msdos mkpart primary ext2 4MiB -1s set 1 boot on

echo Copying boot block
sudo dd if=$BR_OUTPUT/images/syslinux/mbr.bin of=$NBD bs=440 count=1

echo Creating filesystem
sudo mkfs.ext2 -L root -E nodiscard $PART

echo Mounting filesystem
sudo mkdir -p $MOUNT
sudo mount $PART $MOUNT

echo Writing root FS
sudo tar -C $MOUNT -xf $BR_OUTPUT/images/rootfs.tar

echo Installing syslinux
sudo $BR_OUTPUT/host/sbin/extlinux -z --install $MOUNT/boot

if [ $DISK_NAME = server ]
then
	echo Creating share dir
	SHARE_DIR=$MOUNT/share
	sudo mkdir -p $SHARE_DIR
	sudo chmod 770 $SHARE_DIR
	sudo chown 99:99 $SHARE_DIR
fi

echo Unmounting filesystem
sudo umount $MOUNT

echo Deleting NBD
sudo qemu-nbd -d $NBD

echo Unloading NBD module
sudo rmmod nbd

echo Compressing qcow2
rm -f $DISK_QCOW
qemu-img convert -c -f qcow2 -O qcow2 $TEMP_QCOW $DISK_QCOW
rm -f $TEMP_QCOW

ls -lh $DISK_QCOW

echo Done