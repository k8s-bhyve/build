class lsyncd::params {

  case $::osfamily {
    'Debian': {
      $config_dir  = '/etc/lsyncd'
      $config_file = 'lsyncd.conf.lua'
      $rc_config_file = undef
      $rc_config_tmpl = undef
      $package_name = 'lsyncd'
      $package_provider = undef
      $service_name = 'lsyncd'
      $settings = {}
    }
    'FreeBSD': {
      $config_dir  = '/usr/local/etc/lsyncd'
      $config_file = 'lsyncd.conf.lua'
      $rc_config_file = '/etc/rc.conf.d/lsyncd'
      $rc_config_tmpl = "${module_name}/lsyncd_freebsd_rcconf.erb"
      $package_name = 'lsyncd'
      $package_provider = undef
      $logfile = '/var/log/lsyncd.log'
      $service_name = 'lsyncd'
      $settings = {}
    }
    default: {
      fail "Operating system ${::operatingsystem} is not supported yet."
    }
  }

}
