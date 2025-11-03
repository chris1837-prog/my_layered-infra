package terraform.tags

# Rule: every aws_ebs_volume must have a non-empty Backup tag
deny contains msg if {
  some rc in input.resource_changes
  rc.type == "aws_ebs_volume"
  non_delete(rc.change)
  not has_backup_tag(rc.change)
  msg := sprintf("aws_ebs_volume.%s is missing the required Backup tag", [rc.name])
}

# Helper: resource is not being deleted
non_delete(ch) if {
  not ("delete" in ch.actions)
}

# Helper: Backup tag exists and is not empty
has_backup_tag(ch) if {
  after := ch.after
  after != null
  tags := object.get(after, "tags", {})
  v := tags["Backup"]
  v != null
  trim(v, " ") != ""
}





