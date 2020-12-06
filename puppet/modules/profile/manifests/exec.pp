# @summary wrapper for exec
#
# wrapper for exec resource to use it with hiera
#
# @example
#   classes:
#     - profile::exec
#
#   profile::exec::entries:
#     ls: <- title for job
#       command: "ls ~" <- command to execute
#     cd:
#       command: "cd"

class profile::exec (
  $entries = lookup('profile::exec::entries', Hash[String,Hash], 'hash', {})
) {
  create_resources(exec, $entries)
}
