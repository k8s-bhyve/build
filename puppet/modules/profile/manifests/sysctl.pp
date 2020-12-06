class profile::sysctl (
    $entries = {},
) {
  create_resources('sysctl', $entries)
}
