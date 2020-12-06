# @summary wrapper for file
#
# wrapper for file resource to use it with hiera
#
# @example
#   classes:
#     - profile::file
#
#   profile::file::entries:
#     ssh_host_rsa_key:
#       ensure: "present"
#       path: "some/path"
#       group: "some_group"

class profile::file (
  $entries = lookup('profile::file::entries', Hash[String,Hash], 'hash', {})
) {
  create_resources(file, $entries)
}
