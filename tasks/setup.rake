desc 'Install vagrant plugins, get puppetlabs-modules, run r10k, and create a puppetmaster'
task :setup do
  %w[vagrant-vbox-snapshot vagrant-cachier vagrant-vbguest vagrant-hosts vagrant-auto_network vagrant-config_builder].each do |plugin|
    Kernel.system "vagrant plugin list | grep #{plugin} || vagrant plugin install #{plugin}"
  end
#  Rake::Task["modules"].execute
#  system "vagrant up pemaster-vagrant.ops.puppetlabs.net"
  system "vagrant status"
end
