# @summary wrapper for inifile
#
# wrapper for inifile resource to use it with hiera
#
# @example
#   classes:
#     - profile::inifile
#
#   profile::inifile::entries:
#     /tmp/my.ini:
#       ensure: "present"
#       path: "/tmp/my.ini"
#       section: "Manager"
#       setting: "DefaultLimitNOFILE"
#       value: 32768

class profile::inifile (
  $entries = lookup('profile::inifile::entries', Hash[String,Hash], 'hash', {})
) {
  create_resources(ini_setting, $entries)
}
