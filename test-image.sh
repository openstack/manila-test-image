#!/bin/sh

KVM=kvm
if ! which $KVM 2> /dev/null ; then
    KVM=qemu-kvm
fi

qemu-img create -f qcow2 -b client.qcow2 client-test.qcow2
$KVM -m 64 -monitor none -nographic \
    -drive file=client-test.qcow2,if=virtio,format=qcow2 \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0
rm client-test.qcow2
