#
# Cookbook Name:: restpose
# Recipe:: default
#
# Copyright 2012, Ash Berlin
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
include_recipe "build-essential"

# We need to backport xapian so restpose will build
apt_repository "xapian" do
  uri "http://ppa.launchpad.net/xapian-backports/ppa/ubuntu"
  distribution node['lsb']['codename']
  components ["main"]
  key "A0735AD0"
  keyserver "keyserver.ubuntu.com"
end

%w[libxapian-dev python zlib1g-dev uuid-dev].each do |dep|
  package dep
end

remote_file "/tmp/restpose-#{node[:restpose][:version]}.tar.gz" do
  source "https://github.com/downloads/restpose/restpose/restpose-#{node[:restpose][:version]}.tar.gz"
  backup false
  mode "0644"
  # Downloading the file triggers the build
  not_if %Q{([ -x /usr/local/bin/restpose ] && restpose -v | grep -q "restpose version: #{node[:restpose][:version]}")}
  notifies :run, "bash[build restpose]", :immediately
end

bash "build restpose" do
  cwd "/tmp/"
  code <<-EOC
    tar -zxf "/tmp/restpose-#{node[:restpose][:version]}.tar.gz"
    cd restpose-#{node[:restpose][:version]}
    ./configure
    make install
  EOC
  action :nothing
end

file "/tmp/restpose-#{node[:restpose][:version]}.tar.gz" do
  backup false
  action :delete
end

directory "/tmp/restpose-#{node[:restpose][:version]}" do
  action :delete
  recursive true
end

group node['restpose']['group'] do
  system true
end

user node['restpose']['user'] do
  system true
  home "/var/lib/restpose"
  group node['restpose']['group']
end

directory "/var/lib/restpose" do
  owner node['restpose']['user']
end

template "/etc/init/restpose.conf" do
  source "upstart.conf.erb"
  mode "0644"
  backup false
  variables(
    :user => node['restpose']['user'],
    :group => node['restpose']['group'],
    :port => node['restpose']['port']
  )

  notifies :restart, "service[restpose]", :immediately
end

service "restpose" do
  provider Chef::Provider::Service::Upstart
  action [:enable,:start]
end
