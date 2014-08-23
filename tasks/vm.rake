require 'yaml'

namespace :vm do
  desc 'run an agent --test on a given VM'
    task :kick, :node do |t, args|
      node = args[:node]
      system "echo 'sudo -i puppet agent --test --server=pemaster-vagrant.ops.puppetlabs.net' | vagrant ssh #{node}"
    end

  desc 'destroy and re-create a given VM'
    task :recreate, :node do |t, args|
      node = args[:node]
      ANSWERFILE = File.join('.pe_build', 'answers', "#{node}.txt")
      File.delete(ANSWERFILE) if File.file?(ANSWERFILE)
      system "echo 'sudo -i puppet cert clean #{node}' | vagrant ssh pemaster-vagrant.ops.puppetlabs.net"
      system "vagrant destroy -f #{node} ; vagrant up #{node}"
    end

  desc 'Create a basic yaml node entry for a new system'
    task :add, :hostname, :vagrantbox do |t, args|
      name = args[:hostname] || "puppetlabs/debian-7.5-64-nocm"
      box = args[:vagrantbox]
      NODEFILE = File.join('config', "#{name}-vm.yaml")
      abort("${NODEFILE} already exists") if File.file?(NODEFILE)

      node = {"vms"=>[{"name"=>name, "box"=>box, "provision"=>:hosts, "roles"=>["plops-pe-node", "base"]}]}
      File.open(NODEFILE, "w") do |file|
        file.write node.to_yaml
      end
  end
end
