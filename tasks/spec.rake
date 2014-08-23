require 'rspec/core/rake_task'

desc 'run serverspec tests'
  task :serverspec, :node do |t, args|
    node = args[:node]
    RSpec::Core::RakeTask.new(:spec) do |test|
      test.pattern = "spec/#{node}/*_spec.rb"
      test.rspec_opts = "--tag #{node}"
    end
  end
