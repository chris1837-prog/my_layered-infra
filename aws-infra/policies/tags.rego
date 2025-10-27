package terraform.tags

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "aws_ebs_volume"
  non_delete(rc.change)
  not has_backup_tag(rc.change)
  msg := sprintf("aws_ebs_volume.%s is missing the required Backup tag", [rc.name])
}

non_delete(ch) {
  not contains(ch.actions, "delete")
}

has_backup_tag(ch) {
  after := ch.after
  after != null
  tags := object.get(after, "tags", {})
  v := tags["Backup"]
  v != null
  trim(v) != ""
}
