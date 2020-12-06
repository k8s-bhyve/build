define lsyncd::rsyncssh (
  $source    = undef,
  $targetdir = undef,
  $host      = undef,
  $ensure    = present,
  $delete    = false,
  $delay     = 0,
  $options   = {},
) {
  $path = "${lsyncd::config_dir}/sync.d/${name}.conf.lua"

  if $ensure == 'absent' {
    file { $path:
      ensure => $ensure,
      notify => Service['lsyncd'],
    }
  } else {
    file { $path:
      ensure  => $ensure,
      content => template("${module_name}/rsyncssh.conf.lua.erb"),
      mode    => '0644',
      require => File["${lsyncd::config_dir}/sync.d"],
      notify  => Service['lsyncd'],
    }
  }
}
