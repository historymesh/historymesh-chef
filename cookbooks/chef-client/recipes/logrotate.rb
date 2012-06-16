#
# Author:: Ash Berlin (<ash_opscode@firemirror.com>)
# Cookbook Name:: chef
# Recipe:: logrotate
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

logrotate_app "chef-client" do
  source "logrotate"
  rotate_count 5
  path "#{node["chef_client"]["log_dir"]}/*.log"
end
