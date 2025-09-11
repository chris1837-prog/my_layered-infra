package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestIAMModule(t *testing.T) {
	t.Parallel()

	// Terraform options for the test - uses the example directory
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/basic_usage",
		NoColor:      true,
	}

	// Clean up resources after test completion
	defer func() {
		t.Log("Destroying IAM test resources...")
		terraform.Destroy(t, terraformOptions)
		t.Log("IAM test resources destroyed.")
	}()

	t.Log("Applying IAM test resources...")
	terraform.InitAndApply(t, terraformOptions)
	t.Log("IAM test resources applied.")

	// Test 1: Assert engineer role ARN output exists
	t.Run("Engineer role ARN output exists", func(t *testing.T) {
		roleArn := terraform.Output(t, terraformOptions, "engineer_role_arn")
		assert.NotEmpty(t, roleArn, "Engineer IAM role ARN should be output and not empty")
	})
}
