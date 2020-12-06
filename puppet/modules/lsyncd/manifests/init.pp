class lsyncd (
    $package_ensure       = 'present',
    $rsync_package_ensure = 'latest',
    $service_manage       = true,
    $config_dir           = $lsyncd::params::config_dir,
    $config_file          = $lsyncd::params::config_file,
    $rc_config_file       = $lsyncd::params::rc_config_file,
    $rc_config_tmpl       = $lsyncd::params::rc_config_tmpl,
    $settings             = $lsyncd::params::settings,
    $rsync                = {},
    $rsyncssh             = {},
) inherits lsyncd::params {

  file { [$config_dir, "${config_dir}/sync.d"]:
    ensure  => 'directory',
    recurse => true,
    purge   => true,
    notify  => Service['lsyncd'],
  }

  file { "${config_dir}/dodir.lua":
    ensure  => present,
    content => file("${module_name}/dodir.lua"),
    mode    => '0644',
    require => File[$config_dir],
    notify  => Service['lsyncd'],
  }

  file { "${config_dir}/${config_file}":
    ensure  => present,
    content => template("${module_name}/lsyncd.conf.lua.erb"),
    mode    => '0644',
    require => File["${config_dir}/dodir.lua"],
    notify  => Service['lsyncd'],
  }

  package { $lsyncd::params::package_name:
    ensure   => $package_ensure,
    require => File["${config_dir}/${config_file}"],
    provider => $lsyncd::params::package_provider,
  }

  ensure_resource('package', 'rsync', {'ensure' => "$rsync_package_ensure" })

  if $service_manage {
    $service_notify_real = Service[$lsyncd::params::service_name]
  } else {
    $service_notify_real = undef
  }

  if ( $lsyncd::params::rc_config_file ) {
    file { $lsyncd::params::rc_config_file:
      owner   => 'root',
      group   => 0,
      mode    => '0644',
      content => template($lsyncd::params::rc_config_tmpl),
      require => Package[$lsyncd::params::package_name],
      notify  => $service_notify_real,
    }
  }

  service { $lsyncd::params::service_name:
    ensure    => 'running',
    enable    => true,
    hasstatus => true,
    require   => Package[$lsyncd::params::package_name],
  }

  create_resources(lsyncd::rsync, $rsync)
  create_resources(lsyncd::rsyncssh, $rsyncssh)
}
