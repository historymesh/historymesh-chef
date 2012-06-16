#
# Cookbook Name:: application
# Recipe:: django
#
# Copyright 2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

app = node.run_state[:current_app]

include_recipe "python"

###
# You really most likely don't want to run this recipe from here - let the
# default application recipe work it's mojo for you.
###

node.default[:apps][app['id']][node.chef_environment][:run_migrations] = false

## Create required directories

directory "#{app['deploy_to']}/shared/config" do
  owner app['owner']
  group app['group']
  mode '0755'
  recursive true
end

## Create a virtualenv for the app
ve = python_virtualenv app['id'] do
  path "#{app['deploy_to']}/shared/env"
  action :create
end

## First, install any application specific packages
if app['packages']
  app['packages'].each do |pkg,ver|
    package pkg do
      action :install
      version ver if ver && ver.length > 0
    end
  end
end

## Next, install any application specific gems
if app['pips']
  app['pips'].each do |pip,ver|
    python_pip pip do
      version ver if ver && ver.length > 0
      virtualenv ve.path
      action :install
    end
  end
end

if app.has_key?("deploy_key")
  ruby_block "write_key" do
    block do
      f = ::File.open("#{app['deploy_to']}/id_deploy", "w")
      f.print(app["deploy_key"])
      f.close
    end
    not_if do ::File.exists?("#{app['deploy_to']}/id_deploy"); end
  end

  file "#{app['deploy_to']}/id_deploy" do
    owner app['owner']
    group app['group']
    mode '0600'
  end

  template "#{app['deploy_to']}/deploy-ssh-wrapper" do
    source "deploy-ssh-wrapper.erb"
    owner app['owner']
    group app['group']
    mode "0755"
    variables app.to_hash
  end
end

if app["database_master_role"]
  dbm = nil
  # If we are the database master
  if node.run_list.roles.include?(app["database_master_role"][0])
    dbm = node
  else
  # Find the database master
    results = search(:node, "role:#{app["database_master_role"][0]} AND chef_environment:#{node.chef_environment}", nil, 0, 1)
    rows = results[0]
    if rows.length == 1
      dbm = rows[0]
    end
  end

  # we need the django version to render the correct type of settings.py file
  django_version = 1.2
  if app['pips'].has_key?('django') && !app['pips']['django'].strip.empty?
    django_version = app['pips']['django'].to_f
  end

  unless dbm
    Chef::Log.warn("No node with role #{app["database_master_role"][0]}")
  end
end

file "#{app['deploy_to']}/shared/config/__init__.py" do
  owner app['owner']
  group app['group']
  mode "0644"
  content ""
end

# Assuming we have one...
if dbm
  unless app['databases'][node.chef_environment].has_key? 'password'
    passwords = Chef::EncryptedDataBagItem.load("passwords", "postgres")
    app['databases'][node.chef_environment][ 'password' ] = passwords[ app['databases'][node.chef_environment]['username'] ]
  end

  # local_settings.py
  template "#{app['deploy_to']}/shared/config/settings.py" do
    source "settings.py.erb"
    owner app["owner"]
    group app["group"]
    mode "644"
    variables(
      # TODO: restpose is currently hardcoded in the template to localhost
      :db_master => (dbm == node ? '127.0.0.1' : dbm.attribute?('cloud') ? dbm['cloud']['local_ipv4'] : dbm['ipaddress']),
      :database => app['databases'][node.chef_environment],
      :django_version => django_version
    )
  end
end

## Then, deploy
deploy_revision app['id'] do
  # provider HistoryMesh::Antler::Deploy::Revision

  revision app['revision'][node.chef_environment]
  repository app['repository']
  user app['owner']
  group app['group']
  deploy_to app['deploy_to']
  action app['force'][node.chef_environment] ? :force_deploy : :deploy
  ssh_wrapper "#{app['deploy_to']}/deploy-ssh-wrapper" if app['deploy_key']
  shallow_clone true
  purge_before_symlink([])
  create_dirs_before_symlink([])
  symlinks({})
  # Done in the before_migrate block instead
  symlink_before_migrate({})

  environment "DJANGOENV" => "production"
  before_migrate do
    requirements_file = nil
    # look for requirements.txt files in common locations
    if app.has_key?( 'requirements_file' )
      requirements_file = ::File.join(release_path, app['requirements_file'])
    elsif ::File.exists?(::File.join(release_path, "requirements", "#{node[:chef_environment]}.txt"))
      requirements_file = ::File.join(release_path, "requirements", "#{node.chef_environment}.txt")
    elsif ::File.exists?(::File.join(release_path, "requirements.txt"))
      requirements_file = ::File.join(release_path, "requirements.txt")
    end

    if requirements_file
      Chef::Log.info("Installing pips using requirements file: #{requirements_file}")
      pip_cmd = File.join(ve.path, "bin", "pip")
      execute "#{pip_cmd} install -r #{requirements_file}" do
        ignore_failure true
        cwd release_path
      end
    end

    shared_path = @new_resource.shared_path
    link "#{release_path}/antler/configs/production" do
      to "#{shared_path}/config"
    end
    # This shouldn't be needed but the manage.py/django is doing something funny
    link "#{release_path}/antler/production" do
      to "#{shared_path}/config"
    end
  end

  if app['migrate'][node.chef_environment] && node[:apps][app['id']][node.chef_environment][:run_migrations]
    migrate true
    migration_command app['migration_command'] || "#{::File.join(ve.path, "bin", "python")} antler/manage.py migrate"
  else
    migrate false
  end
  before_symlink do
    ruby_block "remove_run_migrations" do
      block do
        if node.role?("#{app['id']}_run_migrations")
          Chef::Log.info("Migrations were run, removing role[#{app['id']}_run_migrations]")
          node.run_list.remove("role[#{app['id']}_run_migrations]")
        end
      end
    end

    execute "cssprepare" do
      command "cssprepare --optimise --extended-syntax antler/static/css/screen > antler/static/css/screen.css"
      user app['owner']
      cwd release_path
    end

    execute "jsprepare" do
      command "jsprepare antler/static/js/common/control.js > antler/static/js/common.js"
      user app['owner']
      cwd release_path
    end
  end
end

template "/etc/nginx/sites-available/historymesh.com" do
  source "django_nginx.conf.erb"
  backup false
  mode "0644"
  variables(
    :app => app['id'],
    :server_name => 'historymesh.com',
    :server_aliases => 'www.historymesh.com',
    :docroot => "#{app['deploy_to']}/current/antler/static",
    :django_admin_static_root => "#{ve.path}/lib/#{ve.interpreter}/site-packages/django/contrib/admin/"
  )
  notifies :restart, "service[nginx]"
end

nginx_site "historymesh.com"
