#This is the Local Tooling and Observability branch

Our goal is drastically reduces the feedback loop for developers working on observability and policy enforcement.
By building these capabilities locally, we can iterate faster, reduce our reliance on shared cloud environments, and ship more reliable features 


#Makefile 
Makefile target make test-tf-policy that runs terraform plan, converts the plan output to JSON, and uses Conftest to validate the plan against our custom infrastructure policies.

it: 
Runs terraform init
Creates a binary plan
Converts that plan into JSON
Runs conftest test with our tags.rego policy

