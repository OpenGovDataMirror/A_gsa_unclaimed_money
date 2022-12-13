require 'bundler/capistrano'
require 'capistrano/ext/multistage'
require './config/boot'
set :stages, %w(development cgi-deployment staging production production-backup)
set :default_stage, "development"

set :web_user, nil
set :application, "unclaimed-money"
set :scm, "git"
set :repository, "https://github.com/GSA/unclaimed_money.git"

set :use_sudo, false
set :deploy_via, :remote_cache

before 'deploy:assets:precompile', 'deploy:symlink_files'
after "deploy:restart", "deploy:cleanup"
after "deploy:setup", "deploy:add_shared_config"


desc "Shows the date/time and commit revision of when the code was most recently deployed for a server"
task :last_deployed do
  deploy_date = ""
  git_revision = ""
  run("#{sudo :as => web_user if web_user} ls -al #{File.join(current_path, 'REVISION')}", :pty => true) do |channel, stream, data|
    deploy_date = data.to_s.split()[5..-2].to_a.join(" ").to_s
  end
  run("#{sudo :as => web_user if web_user} cat #{File.join(current_path, 'REVISION')}", :pty => true) do |channel, stream, data|
    git_revision = data.to_s.split("\n").last
  end
  puts "Last deployed at: #{deploy_date}"
  puts "Git Revision: #{git_revision}"
end

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  desc "Add config dir to shared folder"
  task :add_shared_config do
    sudo "mkdir -p #{deploy_to}/shared/config/initializers"
    sudo "touch #{deploy_to}/shared/log/.gitkeep"
    top.upload('config/initializers/myusa.rb.example', "/tmp/myusa.rb", :via => :scp)
    sudo "mv /tmp/myusa.rb #{deploy_to}/shared/config/initializers/myusa.rb"
  end

  desc "Upload config file"
  task :upload_config_file do
    top.upload('config/initializers/myusa.rb', "#{deploy_to}/shared/config/initializers/myusa.rb", :via => :scp)
  end

  desc "Symlink files"
  task :symlink_files, :roles => :app do
    run "ln -nfs #{deploy_to}/shared/config/*.yml #{release_path}/config/"
    run "ln -nfs #{deploy_to}/shared/config/initializers/myusa.rb #{release_path}/config/initializers/myusa.rb"
  end

  task :update_git_repo_location do
    run "if [ -d #{shared_path}/cached-copy ]; then cd #{shared_path}/cached-copy && git remote set-url origin #{repository}; else true; fi"
  end
end
