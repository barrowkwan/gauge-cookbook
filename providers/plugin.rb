include Chef::Mixin::ShellOut

action :install do
  existing_version = existing_plugin_version(new_resource)
  resource_name = "install gauge plugin #{new_resource.name}#{(" v" << new_resource.version) if new_resource.version}"

  install_command = "gauge --install #{new_resource.name}"

  if new_resource.version
    install_command << " --plugin-version #{new_resource.version}"
  end

  if existing_version && new_resource.version && existing_version != new_resource.version
    remove_plugin(new_resource.user, new_resource.name)
  end

  if !existing_version || (existing_version && new_resource.version && existing_version != new_resource.version)
    if platform_family?('windows')
      chocolatey 'wget'
      ruby_block install_command do
        block do
          shell_out!(install_command, shellout_options(new_resource))
          new_resource.updated_by_last_action(true)
        end
      end
    else
      execute install_command do
        user  new_resource.user
        group new_resource.group
        environment ({
                       'HOME' => node['etc']['passwd'][new_resource.user]['dir'],
                       'USER' => new_resource.user
        })
      end
    end

    new_resource.updated_by_last_action(true)
  end
end

action :remove do
  removed = remove_plugin(new_resource.user, new_resource.name, new_resource.version)
  new_resource.updated_by_last_action(removed)
end

def plugin_dir(user, plugin_name, version=nil)
  plugin_dir = if platform_family?('windows')
    "C:/Users/#{user}/AppData/Roaming/gauge/plugins/#{plugin_name}"
  else
    ::File.join(node['etc']['passwd'][user]['dir'], '.gauge', 'plugins', plugin_name)
  end

  if version
    plugin_dir = ::File.join(plugin_dir, version)
  end

  plugin_dir
end

def remove_plugin(user, plugin_name, version=nil)
  to_remove = plugin_dir(user, plugin_name)

  directory_resource = directory to_remove do
    action    :delete
    recursive true
  end

  directory_resource.updated_by_last_action?
end

def shellout_options(new_resource)
  opts = {user: new_resource.user, group: new_resource.group}

  # windows needs a password, linux needs HOME and USER to be forced
  if platform_family?('windows')
    opts.merge!({
                  password:  new_resource.password,
                  domain: new_resource.domain,
                  env: {
                    'APPDATA'     => "#{ENV['HOMEDRIVE']}\\Users\\#{new_resource.user}\\AppData\\Roaming",
                    'USERPROFILE' => "#{ENV['HOMEDRIVE']}\\Users\\#{new_resource.user}",
                    'HOMEDRIVE'   => ENV['HOMEDRIVE'],
                    'HOMEPATH'    => "\\Users\\#{new_resource.user}"
                  }
    })
  else
    opts.merge!(env: {
                  'HOME' => node['etc']['passwd'][new_resource.user]['dir'],
                  'USER' => new_resource.user
    })
  end

  opts
end

def existing_plugin_version(new_resource)
  version_stdout = shell_out!('gauge --version', shellout_options(new_resource)).stdout
  if version_stdout =~ (/^#{new_resource.name} \((.*)\)/)
    $1
  else
    nil
  end
end
