# manage mail aliases
class mailalias {

  case $::osfamily {
    'FreeBSD': {
      $rootmail_file = '/var/mail/root'
    }
    default: {
      $rootmail_file = '/var/spool/mail/root'
    }
  }

  mailalias { 'root':
    ensure    => present,
    recipient => '/dev/null',
  }

  file { $rootmail_file:
    ensure => absent,
  }

}
