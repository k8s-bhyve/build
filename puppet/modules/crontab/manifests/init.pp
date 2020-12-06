class crontab {

  $purge = lookup('crontab::purge',Boolean, 'first', false)

  resources { 'cron':
    purge  => $purge,
  }

  $crontab_entries = lookup('crontab::crontab_entries', Hash[String,Hash], 'hash', {})
  create_resources (cron, $crontab_entries)
}
