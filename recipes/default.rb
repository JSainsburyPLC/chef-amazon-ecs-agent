#
# Cookbook Name:: amazon-ecs-agent
# Recipe:: default
#
# Copyright (C) 2014 Will Salt
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
include_recipe 'chef-sugar'

package 'apt-transport-https' if ubuntu?

apt_repository 'docker' do
  uri 'https://apt.dockerproject.org/repo'
  trusted true
  distribution "ubuntu-#{node['lsb']['codename']}"
  components ['main']
  only_if { ubuntu? }
end

# create the default log folder
directory node['amazon-ecs-agent']['log_folder'] do
  mode 0755
  action :create
end

directory node['amazon-ecs-agent']['data_folder'] do
  mode 0755
  action :create
end

package "linux-image-extra-#{node['kernel']['release']}" do
  only_if { node['amazon-ecs-agent']['storage_driver'] == 'aufs' }
end

docker_installation_package 'default' do
  version node['amazon-ecs-agent']['docker']['version']
  action :create
  case node[:platform]
  when 'ubuntu','debian'
    package_options '-o Dpkg::Options::="--force-confdef"'
  end
end

# create the docker service

docker_service 'default' do
  storage_driver node['amazon-ecs-agent']['storage_driver']

  if node['amazon-ecs-agent']['storage_driver_opts']
    storage_opts node['amazon-ecs-agent']['storage_driver_opts']
  end

  action [:create, :start]
  log_driver 'gelf'
  log_opts ['gelf-address=udp://localhost:9998']
end


# pull down the latest image
docker_image 'amazon/amazon-ecs-agent'

# start the container and map it to port 8484
docker_container 'amazon-ecs-agent' do
  repo 'amazon/amazon-ecs-agent'
  port '51678:51678'
  tag 'latest'
  env [
    'ECS_DATADIR=/data/',
    'ECS_LOGFILE=/log/ecs-agent.log',
    "ECS_RESERVED_MEMORY=#{node['amazon-ecs-agent']['reserved_memory']}",
    "ECS_LOGLEVEL=#{node['amazon-ecs-agent']['log_level']}",
    "ECS_CLUSTER=#{node['amazon-ecs-agent']['cluster']}",
    "AWS_ACCESS_KEY_ID=#{node['amazon-ecs-agent']['aws_access_key_id']}",
    "AWS_SECRET_ACCESS_KEY=#{node['amazon-ecs-agent']['aws_secret_access_key']}"
  ] + node['amazon-ecs-agent']['docker_additional_env']
  binds [
    "#{node['amazon-ecs-agent']['log_folder']}:/log",
    '/var/run/docker.sock:/var/run/docker.sock',
    "#{node['amazon-ecs-agent']['data_folder']}:/data"
  ] + node['amazon-ecs-agent']['docker_additional_binds']
  action :run
  restart_policy 'always'
end

# ECS doesn't clean old images
# https://aws.amazon.com/blogs/compute/optimizing-disk-usage-on-amazon-ecs/
cron 'clean-ecs-images' do
  time :daily
  action :create
  command 'docker images -q | xargs --no-run-if-empty docker rmi >/dev/null 2>&1'
end
