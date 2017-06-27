zipfile = ::File.join(Chef::Config[:file_cache_path], ::File.basename(node['gauge']['url']))

remote_file zipfile do
  source node['gauge']['url']
  checksum node['gauge']['checksum']
  not_if { ::File.exist?("/opt/local/gauge/.version-#{node['gauge']['version']}") }
end

directory '/opt/local/gauge' do
  owner 'root'
  group 'root'
  mode  '0755'
  recursive true
end

execute "install gauge v#{node['gauge']['version']}" do
  command "rm -rf /opt/local/gauge && mkdir -p /opt/local/gauge/share/gauge && unzip #{zipfile} -d /opt/local/gauge && touch /opt/local/gauge/.version-#{node['gauge']['version']}"
  creates "/opt/local/gauge/.version-#{node['gauge']['version']}"
end

if (node['gauge']['version'].slice(0).to_i + node['gauge']['version'].split('.',2)[1].to_f/10) >= 0.85
  file '/usr/local/bin/gauge' do
    mode  '0755'
    owner 'root'
    group 'root'
    content <<-EOF
#!/bin/bash
#
# This file was generated by chef, any changes will be lost
#
exec /opt/local/gauge/bin/gauge "$@"
EOF
  end
else
  file '/usr/local/bin/gauge' do
    mode  '0755'
    owner 'root'
    group 'root'
    content <<-EOF
#!/bin/bash
#
# This file was generated by chef, any changes will be lost
#
export GAUGE_ROOT=/opt/local/gauge
exec $GAUGE_ROOT/bin/gauge "$@"
EOF
  end
end


file '/usr/local/bin/gauge_screenshot' do
  mode  '0755'
  owner 'root'
  group 'root'
  content <<-EOF
#!/bin/bash
#
# This file was generated by chef, any changes will be lost
#
export GAUGE_ROOT=/opt/local/gauge
exec $GAUGE_ROOT/bin/gauge_screenshot "$@"
EOF
end

template '/opt/local/gauge/share/gauge/gauge.properties' do
  owner 'root'
  group 'root'
  mode  '0644'
end

file zipfile do
  action :delete
  backup false
end
