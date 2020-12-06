# Global Defaults
Exec { path => '/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin' }
$role_config = lookup('role', String, 'first', 'stale')

case size($role_config) {
  0: { fail('Please specify any role') }
  default: {}
}

hiera_include('classes')
