# @summary wrapper for package
#
# wrapper for package resource to use it with hiera
#
# @example
#   classes:
#     - profile::package
#
#   profile::package::entries:
#     ssh_host_rsa_key: <- package name
#       ensure: "present"
#     glpi: <- package name
#       ensure: "absent"

class profile::package (
  $entries = lookup('profile::package::entries', Hash[String,Hash], 'hash', {}),
) {
  create_resources(package, $entries)
}
