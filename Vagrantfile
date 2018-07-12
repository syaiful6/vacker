# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'json'
require 'yaml'

VAGRANT_API_VERSION ||= "2"
confDir = $confDir ||= File.expand_path(File.dirname(__FILE__))

vackerYamlPath = confDir + "/vacker.yaml"
afterScriptPath = confDir + "/after.sh"
aliasesPath = confDir + "/aliases"

require File.expand_path(File.dirname(__FILE__) + '/scripts/vacker.rb')

Vagrant.require_version '>= 2.1.0'


Vagrant.configure(VAGRANT_API_VERSION) do |config|
  if File.exist? aliasesPath then
    config.vm.provision "file", source: aliasesPath, destination: "/tmp/bash_aliases"
    config.vm.provision "shell" do |s|
      s.inline = "awk '{ sub(\"\r$\", \"\"); print }' /tmp/bash_aliases > /home/vagrant/.bash_aliases"
    end
  end

  if File.exists? vackerYamlPath then
    settings = YAML::load(File.read(vackerYamlPath))
  else
    abort "Vacker seettings file not found #{confDir}"
  end

  Vacker::configure(config, settings)

  if File.exist? afterScriptPath then
    config.vm.provision "shell", path: afterScriptPath, privileged: false, keep_color: true
  end

  if Vagrant.has_plugin?('vagrant-hostsupdater')
    config.hostsupdater.aliases = settings['sites'].map { |site| site['map'] }
  elsif Vagrant.has_plugin?('vagrant-hostmanager')
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.aliases = settings['sites'].map { |site| site['map'] }
  end
end
