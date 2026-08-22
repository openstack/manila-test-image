#!/bin/sh
# Post-build hook: add a "manila" login user as a uid-0 alias of root.
#
# The images log in as "manila" by default (matching the generic driver's
# service_instance_user) while sharing root's home and password. buildroot's
# mkusers refuses to create a uid-0 account, so the entry is appended here,
# after the target filesystem has been finalized.

set -e

TARGET_DIR="$1"
PASSWD="${TARGET_DIR}/etc/passwd"
SHADOW="${TARGET_DIR}/etc/shadow"

if ! grep -q '^manila:' "${PASSWD}"; then
    echo 'manila:x:0:0:manila:/root:/bin/sh' >> "${PASSWD}"
fi

if [ -f "${SHADOW}" ] && ! grep -q '^manila:' "${SHADOW}"; then
    # Reuse root's password entry so "manila" shares root's password.
    root_entry="$(grep '^root:' "${SHADOW}")"
    echo "manila:${root_entry#root:}" >> "${SHADOW}"
fi
