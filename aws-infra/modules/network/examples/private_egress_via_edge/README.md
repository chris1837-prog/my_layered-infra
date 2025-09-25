# Private Egress via Edge Example

This example provisions a minimal setup to validate **egress
connectivity** from a private subnet instance through an Edge NAT
instance.

It is used in combination with the script
[`scripts/egress-test.sh`](../../../scripts/egress-test.sh) to ensure
that private instances can reach the internet through the Edge.

## How to Use

``` bash
cd aws-infra/modules/network/examples/private_egress_via_edge
terraform init
terraform apply -auto-approve
```

After deployment, connect to the private instance via the generated SSH
key and run the script:

``` bash
scp -i ./network_test_key.pem ../../../../scripts/egress-test.sh ubuntu@<private_instance_ip>:/tmp/
ssh -i ./network_test_key.pem ubuntu@<private_instance_ip> "bash /tmp/egress-test.sh"
```

Destroy resources when done:

``` bash
terraform destroy -auto-approve
```

## Notes

-   This example is intended for **testing and validation only**.\
-   It demonstrates the C3 scope: *Edge NAT egress validation + AppDB
    integration*.\
-   In a real environment, automation (e.g., GitHub Actions, Terratest)
    could run these checks automatically.\
    At the moment, however, automation is **out of scope** for C3 and
    should be considered in later stages.\
-   State files (`*.tfstate`) and the generated SSH key
    (`network_test_key.pem`) are ignored via `.gitignore` to prevent
    accidental commits.
