# C5 Area 1 Bootstrap Notes

This folder intentionally does **not** re-run bootstrap Terraform. Re-use the shared `layered_qa` bootstrap stack (per Alejandro’s guidance), and only test incremental changes under `aws-infra/environments/examples/c5-area1`.

Keep this directory around so state files or backend configs created during local experiments can be ignored safely.
