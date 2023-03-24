#  NFS, FUSE 
Для выполнения этого действия требуется установить приложением git:
`git clone https://github.com/altyn-kenzhebaev/nfs_fuse-hw5.git`
В текущей директории появится папка с именем репозитория. В данном случае hw-1. Ознакомимся с содержимым:
```
cd nfs_fuse-hw5
ls -l
freeipa_script.sh
nfsc_script.sh
nfss_script.sh
README.md
Vagrantfile
```
Здесь:
- README.md - файл с данным руководством
- Vagrantfile - файл описывающий виртуальную инфраструктуру для `Vagrant`
- freeipa_script.sh - файл-скрипт, разворачивающий FreeIPA сервер (сервер Kerberos)
- nfss_script.sh - файл-скрипт, разворачивающий сервер NFS
- nfsc_script.sh - файл-скрипт, разворачивающий клиент NFS
### Разбор Vagrantfile
Данный Vagrantfile разворачивает 3 виртульные машины:
```
MACHINES = {
    :freeipa => {
        :box_name => "ftweedal/freeipa-workshop",
        :ip_addr => '192.168.50.100',
        :script => 'freeipa_script.sh',
        :cpus => 2,
        :memory => 2048,
    },
    :nfss => {
        :box_name => "centos/7",
        :ip_addr => '192.168.50.10',
        :script => 'nfss_script.sh',
        :cpus => 1,
        :memory => 512,
    },
    :nfsc => {
        :box_name => "centos/7",
        :ip_addr => '192.168.50.11',
        :script => 'nfsc_script.sh',
        :cpus => 1,
        :memory => 512,
    },
}
```
Через переменные box_name, ip_addr, script, cpus, memory задаем параметры ВМ и выполням свой provision-скрипт на каждом сервере:
```
Vagrant.configure("2") do |config|
  MACHINES.each do |boxname, boxconfig|
      config.vm.define boxname do |box|
          box.vm.box = boxconfig[:box_name]
          box.vm.host_name = boxname.to_s + ".test.local"
          box.vm.network "private_network", ip: boxconfig[:ip_addr], virtualbox__intnet: "net1"
          box.vm.provider :virtualbox do |vb|
            vb.memory = boxconfig[:memory]
            vb.cpus = boxconfig[:cpus] 	        
          end
          box.vm.provision "shell", path: boxconfig[:script]
      end
  end
end
```
### Разворачивание FreeIPA, в целях поддержки аутентификации Kerberos
Данный образ ftweedal/freeipa-workshop, уже предустановленным ПО FreeIPA, остается всего лишь настроить сервер командой:
```
ipa-server-install --no-host-dns --mkhomedir -r TEST.LOCAL -n test.local --hostname=freeipa.test.local --admin-password=vagrant_123 --ds-password=vagrant_123 <<EOF
y
y
y

n
y
EOF
```
### Разворачивание сервера NFS
Требуется следующее ПО для работы сервера NFS, и поддержки аутентификации Kerberos:
```
yum install nfs-utils ipa-client policycoreutils-python -y
```
Настройки для добавления данного сервера к серверу FreeIPA:
```
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
```
Настройка FreeIPA для поддерки Kerberos:
```
kinit admin <<EOF
vagrant_123
EOF

ipa service-add NFS/nfss.test.local
ipa-getkeytab -p NFS/nfss.test.local@TEST.LOCAL -k /etc/krb5.keytab

sed -i '/^#Domain/s/^#//;/Domain = /s/=.*/= test.local/' /etc/idmapd.conf
```
Настройки файрвола для разворачивания NFS:
```
systemctl enable firewalld --now
firewall-cmd --add-service={nfs,nfs3,mountd,rpc-bind} --permanent
firewall-cmd --reload
```
Настройка NFS:
```
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
```
### Разворачивание клиента NFS
Требуется следующее ПО для работы клиента NFS, и поддержки аутентификации Kerberos:
```
yum groups install -y "Network File System Client"
yum install ipa-client -y
```
Настройки для добавления данного сервера к серверу FreeIPA:
```
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
```
Настройка клиента NFS:
```
kinit admin <<EOF
vagrant_123
EOF

systemctl enable firewalld --now

echo "nfss.test.local:/srv/share/ /mnt nfs sec=krb5,x-systemd.automount 0 0" >> /etc/fstab 
systemctl enable nfs-secure --now

systemctl daemon-reload 
systemctl restart remote-fs.target
```
# Проверка функционала
Проверим клиент подключен ли NFS:
```
vagrant ssh nfsc
Last login: Fri Mar 24 07:16:30 2023 from 10.0.2.2
[vagrant@nfsc ~]$ sudo -i
[root@nfsc ~]# df -h
Filesystem                  Size  Used Avail Use% Mounted on
devtmpfs                    237M     0  237M   0% /dev
tmpfs                       244M     0  244M   0% /dev/shm
tmpfs                       244M  4.5M  240M   2% /run
tmpfs                       244M     0  244M   0% /sys/fs/cgroup
/dev/sda1                    40G  3.3G   37G   9% /
__nfss.test.local:/srv/share   40G  3.3G   37G   9% /mnt__
tmpfs                        49M     0   49M   0% /run/user/1000
[root@nfsc ~]# showmount -e nfss.test.local
Export list for nfss.test.local:
/srv/share 192.168.50.11
```