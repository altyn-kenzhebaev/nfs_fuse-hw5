#!/bin/bash

yum groups install -y "Network File System Client"
yum install ipa-client -y

echo "192.168.50.100 freeipa.test.local freeipa" >> /etc/hosts

cat << EOF > /etc/resolv.conf 
search test.local
nameserver 192.168.50.100
EOF

ipa-client-install --domain=test.local --server=freeipa.test.local --realm=TEST.LOCAL <<EOF
y
y
admin
vagrant_123
EOF

kinit admin <<EOF
vagrant_123
EOF

systemctl enable firewalld --now

echo "nfss.test.local:/srv/share/ /mnt nfs sec=krb5,x-systemd.automount 0 0" >> /etc/fstab 
systemctl enable nfs-secure --now

systemctl daemon-reload 
systemctl restart remote-fs.target