# C3 -- Edge NAT Egress Validation + AppDB Integration

## 🎯 Goal

This document describes how to validate egress connectivity from a
private subnet instance through an Edge NAT instance.\
It complements the Bash script `scripts/egress-test.sh` and demonstrates
how to use the existing example\
`aws-infra/modules/network/examples/private_egress_via_edge`.

------------------------------------------------------------------------

## 📂 Structure

    scripts/
     └── egress-test.sh

    aws-infra/modules/network/examples/private_egress_via_edge/
     ├── main.tf
     ├── outputs.tf
     ├── versions.tf
     ├── templates/
     │   └── edge_init.sh.tftpl

    docs/
     └── C3_EDGE_NAT_APPDB.md

------------------------------------------------------------------------

## 🚀 How to Test

### 1. Deploy the Infrastructure

``` bash
cd aws-infra/modules/network/examples/private_egress_via_edge
terraform init
terraform apply -auto-approve
```

### 2. Use the Generated SSH Key

After apply, you can retrieve the generated SSH key and IPs from the
Terraform outputs:

``` bash
terraform output ssh_private_key_file
terraform output edge_public_ip
terraform output private_test_private_ip
```

Example SSH into the Edge instance:

``` bash
ssh -i ./network_test_key.pem ubuntu@<edge_public_ip>
```

From the Edge instance, you can forward into the private instance or
connect directly, depending on your setup.

### 3. Run the Script

Copy the script to the private instance and execute it:

``` bash
scp -i ./network_test_key.pem scripts/egress-test.sh ubuntu@<private_test_private_ip>:/tmp/
ssh -i ./network_test_key.pem ubuntu@<private_test_private_ip> "bash /tmp/egress-test.sh"
```

### 4. Expected Result

-   JSON output containing `dns`, `https`, and `package_repo` fields.\
-   Exit code = 0 on success, 1 on failure.

Example output:

``` json
{
  "dns": { "status": "success", "ip": "142.250.74.206" },
  "https": { "status": "success", "url": "https://www.google.com" },
  "package_repo": { "status": "success", "url": "http://deb.debian.org/debian/dists/stable/Release" }
}
```

### 5. Destroy the Infrastructure

``` bash
terraform destroy -auto-approve
```

------------------------------------------------------------------------

## ✅ Acceptance Criteria

-   Edge and private test instance start successfully.\
-   NAT routing allows egress from the private subnet.\
-   `egress-test.sh` returns **success** for DNS, HTTPS, and Package
    Repo.\
-   Failure drill: stop the NAT instance → tests fail. Restart the NAT
    instance → tests succeed.

------------------------------------------------------------------------

## 📌 Notes

-   Do not modify the module itself (`modules/edge`).\
-   Only Example + Script + Scoped Documentation.\
-   This fulfills the C3 scope: *Egress validation from a private
    instance via Edge NAT*.
