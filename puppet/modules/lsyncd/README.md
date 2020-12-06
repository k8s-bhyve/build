# puppet-lsyncd

# Usage
To configure a replication via a Puppet resource:
```puppet
lsyncd::rsync { 'myawesomereplication':
  source  => '/tmp/source',
  target  => '/tmp/target',
  options => {
    'archive': true,
  }
```

Or via Hiera:
```yaml
lsyncd::settings:
  logfile: '"/var/log/lsyncd.log"'
  statusFile: '"/var/log/lsyncd.status"'
  statusInterval: 1
  maxProcesses: 1
  insist: 1

lsyncd::rsync:
  myawesomereplication-rsync:
    source: /usr/local/source
    target: /usr/local/target
    options:
      archive: true

lsyncd::rsyncssh:
  myawesomereplication-rsyncssh:
    source: /usr/local/source
    targetdir: /usr/local/target
    delete: true
    delay: 0
    host: target-hostname
    options:
      archive: true
      compress: true
```

# Notes

you may want to increase fs.inotify.max_user_watches sysctl params
