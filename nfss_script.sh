#!/bin/bash

yum install nfs-utils ipa-client policycoreutils-python -y

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

ipa service-add NFS/nfss.test.local
ipa-getkeytab -p NFS/nfss.test.local@TEST.LOCAL -k /etc/krb5.keytab

sed -i '/^#Domain/s/^#//;/Domain = /s/=.*/= test.local/' /etc/idmapd.conf

systemctl enable firewalld --now
firewall-cmd --add-service={nfs,nfs3,mountd,rpc-bind} --permanent
firewall-cmd --reload

systemctl enable nfs --now

mkdir -p /srv/share/upload 

chown -R nfsnobody:nfsnobody /srv/share 
chmod 0777 /srv/share/upload

semanage fcontext -a -t public_content_rw_t "/srv/share(/.*)?"
restorecon -R /srv/share
setsebool -P nfs_export_all_rw on
setsebool -P nfs_export_all_ro on

cat << EOF > /etc/exports 
/srv/share 192.168.50.11(rw,sec=krb5:krb5i:krb5p,sync,root_squash) 
EOF

exportfs -r