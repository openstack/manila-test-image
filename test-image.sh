#!/bin/sh

CONFIG_DIR=/tmp/configdir
CONFIG_ISO=/tmp/configdrive.iso
TEST_IMG=/tmp/client-test.qcow2

# Create config-drive ISO
mkdir -p $CONFIG_DIR/ec2/2009-04-04
(
    echo -n '{"public-keys": {"0": {"openssh-key": "'
    cat ~/.ssh/id_rsa.pub | tr -d '\n'
    echo -n '\\n"}}}'
) > $CONFIG_DIR/ec2/2009-04-04/meta-data.json
mkisofs -R -V config-2 -o $CONFIG_ISO $CONFIG_DIR 2> /dev/null
rm -rf $CONFIG_DIR

# Create temporary overlay
qemu-img create -f qcow2 -b $(pwd)/client.qcow2 $TEST_IMG

# Test the image
KVM=kvm
if ! which $KVM 2> /dev/null ; then
    KVM=qemu-kvm
fi
$KVM -m 64 -monitor none -nographic \
    -drive file=$TEST_IMG,if=virtio,format=qcow2 \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -cdrom $CONFIG_ISO

rm $TEST_IMG $CONFIG_ISO
