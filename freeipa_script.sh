#!/bin/bash

ipa-server-install --no-host-dns --mkhomedir -r TEST.LOCAL -n test.local --hostname=freeipa.test.local --admin-password=vagrant_123 --ds-password=vagrant_123 <<EOF
y
y
y

n
y
EOF