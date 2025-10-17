package policies
import rego.v1

deny[msg] if {
  some rc in input.resource_changes
  rc.type == "aws_ebs_volume"
  not contains(rc.change.actions, "delete")
  rc.change.after != null

  tags := object.get(rc.change.after, "tags", {})
  not has_nonempty_backup(tags)

  msg := sprintf("aws_ebs_volume.%s is missing the required Backup tag", [rc.name])
}

has_nonempty_backup(tags) if {
  v := tags["Backup"]
  is_string(v)
  trim(v) != ""
}