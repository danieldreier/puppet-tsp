require 'yaml'
require 'fileutils'
require 'certificate_authority'

repo = 'infrastructure'

desc 'Get puppetlabs-modules with git and run r10k'
task :modules do
  PROJECT_ROOT = File.join('src', 'projects')
  REPO_PATH = File.join(PROJECT_ROOT, repo).to_s

  git_action = 'clone' # clone by default
  git_action = 'pull' if File.exist?("#{REPO_PATH}/.git")

#  Kernel.system 'git', git_action, "git@github.com:puppetlabs/#{repo}.git", REPO_PATH
  Rake::Task["r10k"].execute
end

desc 'run r10k to deploy 3rd party modules'
task :r10k do
  FileUtils::mkdir_p File.join('src', 'modules')
  Dir.chdir('src'){
    %x[#{"PUPPETFILE=#{"projects/#{repo}"}/Puppetfile r10k --verbose info puppetfile install"}]
  }
end
