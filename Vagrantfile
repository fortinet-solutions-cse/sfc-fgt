# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"
ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  #config.proxy.http     = "#{ENV['http_proxy']}"
  #config.proxy.https    = "#{ENV['https_proxy']}"
  #config.proxy.no_proxy = "localhost,127.0.0.1,192.168.1.0/24"
  config.vm.box = "#{ENV['UBUNTU_VBOX_NAME']}"
  #config.vm.box_url = "file://./#{ENV['UBUNTU_VBOX_IMAGE']}"
  config.vm.provider :libvirt do |v|
    v.memory = 2048
    v.cpus = 1
  end

  config.vm.define "#{ENV['CLASSIFIER1_NAME']}" do | h |
    h.vm.host_name = "#{ENV['CLASSIFIER1_NAME']}"
    h.vm.network :private_network,
      :ip => "#{ENV['CLASSIFIER1_IP']}",
      :mac => "#{ENV['CLASSIFIER1_VAGRANT_MAC']}"
  end

  config.vm.define "#{ENV['SFF1_NAME']}" do | h |
    h.vm.host_name = "#{ENV['SFF1_NAME']}"
    h.vm.network :private_network,
      :ip => "#{ENV['SFF1_IP']}",
      :mac => "#{ENV['SFF1_VAGRANT_MAC']}"
  end

  config.vm.define "#{ENV['SF1_NAME']}" do | h |
    h.vm.host_name = "#{ENV['SF1_NAME']}"
    h.vm.network :private_network,
      :ip => "#{ENV['SF1_IP']}",
      :mac => "#{ENV['SF1_VAGRANT_MAC']}"
  end

  config.vm.define "#{ENV['SF2_NAME']}" do | h |
    h.vm.host_name = "#{ENV['SF2_NAME']}"
    h.vm.network :private_network,
      :ip => "#{ENV['SF2_IP']}",
      :mac => "#{ENV['SF2_VAGRANT_MAC']}"
  end

  config.vm.define "#{ENV['SFF2_NAME']}" do | h |
    h.vm.host_name = "#{ENV['SFF2_NAME']}"
    h.vm.network :private_network,
      :ip => "#{ENV['SFF2_IP']}",
      :mac => "#{ENV['SFF2_VAGRANT_MAC']}"
  end

  config.vm.define "#{ENV['CLASSIFIER2_NAME']}" do | h |
    h.vm.host_name = "#{ENV['CLASSIFIER2_NAME']}"
    h.vm.network :private_network,
      :ip => "#{ENV['CLASSIFIER2_IP']}",
      :mac => "#{ENV['CLASSIFIER2_VAGRANT_MAC']}"
  end

  config.vm.define "#{ENV['SF2_PROXY_NAME']}" do | h |
    h.vm.host_name = "#{ENV['SF2_PROXY_NAME']}"
    h.vm.network :private_network,
      :ip => "#{ENV['SF2_PROXY_IP']}",
      :mac => "#{ENV['SF2_PROXY_VAGRANT_MAC']}"
  end
end
