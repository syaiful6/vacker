class Vacker
  def Vacker.configure(config, settings)
    # set the VM provider
    ENV['VAGRANT_DEFAULT_PROVIDER'] = settings["provider"] ||= "provider"

    # configure local variable to access scripts from remote location
    scriptDir = File.dirname(__FILE__)

    # allow SSH Agent Forward from The Box
    config.ssh.forward_agent = true

    # Configure The Box
    config.vm.define settings["name"] ||= "vacker"
    config.vm.box = settings["box"] ||= "ubuntu/xenial64"
    config.vm.box_version = settings["version"] || ">= 6.0.0"
    config.vm.hostname = settings["hostname"] ||= "vacker"

    # Configure a private Network IP
    if settings["ip"] != "autonetwork"
      config.vm.network :private_network, ip: settings["ip"] ||= "192.168.10.10"
    else
      config.vm.network :private_network, :ip => "0.0.0.0", :auto_network => true
    end

    if settings.has_key?("networks")
      settings["networks"].each do |net|
        config.vm.network net["type"], ip: net["ip"], bridge: net["bridge"] ||= nil, netmask: net["netmask"] ||= "255.255.255.0"
      end
    end

    config.vm.provider "virtualbox" do |vb|
      vb.name = settings["name"] ||= "vacker"
      vb.customize ["modifyvm", :id, "--memory", settings["memory"] ||= "2048"]
      vb.customize ["modifyvm", :id, "--cpus", settings["cpus"] ||= "1"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", settings["natdnshostresolver"] ||= "on"]
      vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
      if settings.has_key?("gui") && settings["gui"]
        vb.gui = true
      end
    end

    # Override Default SSH port on the host
    if (settings.has_key?("default_ssh_port"))
      config.vm.network :forwarded_port, guest: 22, host: settings["default_ssh_port"], auto_correct: false, id: "ssh"
    end

    if (settings.has_key?("ports"))
      settings["ports"].each do |port|
        port["guest"] ||= port["to"]
        port["host"] ||= port["send"]
        port["protocol"] ||= "tcp"
      end
    else
      settings["ports"] = []
    end

    # Default port forwarding
    default_ports = {
      80 => 8000,
      443 => 44300
    }

    unless settings.has_key?("default_ports") && settings["default_ports"] == false
      default_ports.each do |guest, host|
        unless settings["ports"].any? { |mapping| mapping["guest"] == guest }
          config.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
        end
      end
    end

    # add custom ports from configuration
    if settings.has_key?("ports")
      settings["ports"].each do |port|
        config.vm.network "forwarded_port", guest: port["guest"], host: port["host"], protocol: port["protocol"], auto_correct: true
      end
    end

    if settings.include? 'authorize'
      if File.exists? File.expand_path(settings["authorize"])
        config.vm.provision "shell" do |s|
          s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo \"\n$1\" | tee -a /home/vagrant/.ssh/authorized_keys"
          s.args = [File.read(File.expand_path(settings["authorize"]))]
        end
      end
    end

    if settings.include? 'keys'
      if settings["keys"].to_s.length == 0
        puts "Check your Homestead.yaml file, you have no private key(s) specified."
        exit
      end
      settings["keys"].each do |key|
        if File.exists? File.expand_path(key)
          config.vm.provision "shell" do |s|
            s.privileged = false
            s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
            s.args = [File.read(File.expand_path(key)), key.split('/').last]
          end
        else
          puts "Check your vacker.yaml, the path to your private key does not exists."
          exit
        end
      end
    end

    if settings.include? 'copy'
      settings["copy"].each do |file|
        config.vm.provision "file" do |f|
          f.source = File.expand_path(file["from"])
          f.destination = file["to"].chomp('/') + "/" + file["from"].split('/').last
        end
      end
    end

    if settings.include? 'folders'
      settings["folders"].each do |folder|
        if File.exists? File.expand_path(folder["map"])
          mount_opts = []

          if (folder["type"] == "nfs")
            mount_opts = folder["mount_options"] ? folder["mount_options"] : ['actimeo=1', 'nolock']
          elsif (folder["type"] == "smb")
            mount_opts = folder["mount_options"] ? folder["mount_options"] : ['vers:3.02', 'mfsymlinks']
          end

          options = (folder["options"] || {}).merge({ mount_options: mount_opts })

          options.keys.each{|k| options[k.to_sym] = options.delete(k) }

          config.vm.synced_folder folder["map"], folder["to"], type: folder["type"] ||= nil, **options

          if (folder["type"] == "nfs")
            if Vagrant.has_plugin?("vagrant-bindfs")
              config.bindfs.bind_folder folder["to"], folder["to"]
            end
          end
        else
          config.vm.provison "shell" do |s|
            s.inline = ">&2 echo \"Unable to mount one of your folders. Please check your folders in Homestead.yaml\""
          end
        end
      end
    end

    config.vm.provision :docker
    config.vm.provision :docker_compose, yml: settings["docker-compose"] ||= "/vagrant/docker-compose.yml", rebuild: true, run: "always"
  end
end
