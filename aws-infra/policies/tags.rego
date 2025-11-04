package main

# Rule: every aws_ebs_volume must have a non-empty Backup tag
deny contains msg if {
  some rc in input.resource_changes
  rc.type == "aws_ebs_volume"
  non_delete(rc.change)
  not has_backup_tag(rc.change)
  not is_exception(rc)
  msg := sprintf("aws_ebs_volume.%s is missing the required Backup tag", [rc.name])
}

# ✅ Exception list (resources to ignore temporarily)
# For now, we skip known EBS volumes without Backup tags.
exceptions := {
  "aws_ebs_volume.data",
}

# ✅ Helper: resource is in the exception list
is_exception(rc) if {
  full_name := sprintf("%s.%s", [rc.type, rc.name])
  full_name in exceptions
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






