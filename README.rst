==================
Manila Test Image
==================

A tiny bootable Linux image used as a test guest for `OpenStack Manila
<https://docs.openstack.org/manila/latest/>`_ (and other OpenStack
testing). It is built with `Buildroot <https://buildroot.org/>`_ and is
optimized for size and fast boot, targeting x86_64 guests running under
QEMU/KVM.

The image is built and maintained **purely for CI and development
testing** of OpenStack. See `Support scope`_ for what that means.

What's in the image
-------------------

* Linux kernel 7.3.1 (includes the Ceph client with CephX
  ``aes256-cts-hmac-sha384-192`` support)
* BusyBox userland (musl libc)
* SSH server (Dropbear)
* NFSv3/v4 client and server utilities
* CIFS client, Samba client tooling
* CephFS kernel client
* Cloud-init-style metadata support: SSH keys are fetched at boot from
  the EC2-style metadata service (``169.254.169.254``) or from a
  config-drive
* ACPI power-button handling (a ``nova stop`` on a non-ACPI guest is a
  hard power-off; this image shuts down cleanly)

Building locally
----------------

Assumed platform
~~~~~~~~~~~~~~~~

A Linux x86_64 host with root (or passwordless ``sudo``) access. The
build needs to attach a disk via NBD, partition and format it, and mount
the result, so it cannot run unprivileged. ``init-buildroot.sh`` will
install most missing dependencies for you on Ubuntu.

Required tools: ``curl``, ``unzip``, ``bc``, ``python3``, ``quilt``,
``parted``, ``qemu-utils`` (``qemu-nbd``/``qemu-img``),
``build-essential``, plus ``flex``, ``bison``, ``texinfo`` and
``gettext`` for the Buildroot toolchain.

Ubuntu::

    sudo apt-get -y install curl unzip bc python3 quilt parted qemu-utils \
        build-essential gcc-multilib flex bison texinfo gettext

Fedora::

    sudo dnf -y install curl unzip bc python3 quilt parted qemu-img \
        gcc-c++ make glibc-devel.i686 flex bison texinfo gettext

A full build downloads Buildroot 2025.02.14 and the Linux sources
(several hundred MiB into ``./download``) and takes on the order of
30-60 minutes on a modern machine.

Build steps
~~~~~~~~~~~

Everything is driven by one script::

    ./run-buildroot.sh

This downloads and patches Buildroot, assembles the filesystem overlay,
builds the image, and produces ``client.qcow2``.

The individual steps, if you need them::

    ./init-buildroot.sh              # download + patch buildroot (once)
    ./make-bootable-disk.sh client   # output-client/ -> client.qcow2

Cleaning up, to build completely from scratch::

    rm -rf buildroot output* overlay*
    sudo rm *.qcow2

See ``doc/building.txt`` and ``doc/configuring.txt`` for details on the
build pipeline and on editing the Buildroot/BusyBox/kernel
configurations.

Resulting image
~~~~~~~~~~~~~~~

* ``client.qcow2`` — about 17 MiB compressed, a 120 MiB virtual disk
  with a single bootable ext4 (journaled) partition, syslinux/extlinux
  bootloader.

Booting the image
-----------------

Requirements to boot under KVM
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

* 64 MiB of RAM (measured minimum is ~42 MiB; 64 MiB is the tested and
  supported value)
* 1 vCPU
* VirtIO disk as the root device (the kernel command line uses
  ``root=/dev/vda1``)
* DHCP on the first NIC (``eth0``, VirtIO or e1000)
* ACPI enabled (for clean shutdown on power button)
* Serial console on ``ttyS0`` at 115200 baud is where boot messages and
  the login prompt appear

Quick smoke test
~~~~~~~~~~~~~~~~

With ``kvm``, ``mkisofs`` and an SSH key in ``~/.ssh/id_rsa.pub``::

    ./test-image.sh

This creates a temporary config-drive with your SSH key, boots
``client.qcow2`` with 64 MiB of RAM, and drops you on the serial
console.

Logging in
~~~~~~~~~~

The default login user is ``manila`` (a uid-0 alias of root, matching
the generic driver's ``service_instance_user``), sharing root's
password. The console login is ``manila`` / ``zorilla`` (or
``root`` / ``zorilla``). SSH keys from the metadata service or
config-drive are installed for root at boot.

Using the image with OpenStack
------------------------------

The image is designed to be imported into Glance and used as the
generic driver's service instance (and as a test guest for share
mounts)::

    openstack image create --disk-format qcow2 \
        --container-format bare --file client.qcow2 manila-test-image

* Nova's config-drive (or the metadata service) supplies the SSH public
  key at boot; no other provisioning is needed.
* The image expects a VirtIO root disk and DHCP networking, which
  Nova provides by default with the ``virtio`` bus and a neutron
  network.
* For the Manila generic driver, set ``service_image_name``,
  ``service_instance_user = manila`` and the matching
  ``service_instance_password``.

CI
--

Changes are gated by Zuul (see ``.zuul.yaml``):

* ``openstack-tox-bashate`` — shell linting of all scripts
* ``manila-test-image-build`` — a full clean-room build of
  ``client.qcow2`` on every check and gate

Successful post-merge builds of ``master`` are published by the
``manila-test-image-publish-artifacts`` job to
https://tarballs.opendev.org/openstack/manila-test-image

Limitations
-----------

* x86_64/QEMU-KVM only. No other architecture or hypervisor is tested.
* The kernel command line hard-codes ``root=/dev/vda1`` and the
  ``kvm-clock`` clock source, so the image assumes a KVM-style
  hypervisor with a VirtIO root disk.
* Only the *client* image is built today. The server variant
  (``conf/buildroot-server.config`` and ``server-files/``) remains in
  the tree but is not assembled or built by ``run-buildroot.sh``; a
  historical ``server.qcow2`` can be built by extending
  ``BUILD_IMAGES`` and the overlay assembly.
* The serial console is the primary (and tested) console; VGA output
  is not exercised.

Support scope
-------------

This image is built and maintained **purely for CI and development
testing of OpenStack**. In particular:

* It is not a production appliance. It ships well-known default
  credentials and a minimal BusyBox userland.
* It receives no scheduled security updates; components are bumped
  when CI needs them (e.g. kernel bumps for CephX interoperability),
  not on a CVE-driven schedule.
* No compatibility guarantees are made across releases; consumers in
  OpenStack CI (e.g. Manila's devstack/grenade/tempest jobs) are the
  only supported users.
* Best-effort help only, from the Manila community (see below).

Contributing
------------

Development follows the usual OpenStack workflow:

* Code review happens on Gerrit at
  https://review.opendev.org (project ``openstack/manila-test-image``).
* Clone with ``git review``-compatible remotes and submit changes with::

      git review

* Every commit must be signed off (``git commit -s``).
* Shell changes must pass ``bashate``; run ``tox -e bashate`` (or
  ``pre-commit run --all-files`` if you use pre-commit) before pushing.

Where maintainers hang out
--------------------------

* IRC: ``#openstack-manila`` on `OFTC <https://www.oftc.net/>`_
* Mailing list: `openstack-discuss
  <https://lists.openstack.org/cgi-bin/mailman/listinfo/openstack-discuss>`_
  (use ``[manila]`` in the subject)
* Weekly Manila team meeting — see the `Manila team meeting page
  <https://meetings.opendev.org/#Manila_Team_Meeting>`_
* Bugs are tracked under the `manila project on Launchpad
  <https://bugs.launchpad.net/manila>`_

License
-------

GPL-2.0-only. See ``COPYING`` for the full license text.
