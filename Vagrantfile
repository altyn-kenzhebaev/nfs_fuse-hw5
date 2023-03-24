# -*- mode: ruby -*-
# vim: set ft=ruby :

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
