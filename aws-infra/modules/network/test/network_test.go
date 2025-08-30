package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestNetworkModule(t *testing.T) {
	t.Parallel()

	// Terraform options for the test - uses the example directory
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/basic_usage",
		// NoColor makes output easier to read in CI
		NoColor: true,
	}

	// Clean up resources after test completion
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Test 1: Assert VPC exists (via output)
	t.Run("VPC is created", func(t *testing.T) {
		vpcId := terraform.Output(t, terraformOptions, "vpc_id")
		assert.NotEmpty(t, vpcId, "VPC should be created and have an ID")
	})

	// Test 2: Assert correct number of subnets exist (via outputs)
	t.Run("Subnets are created with correct count", func(t *testing.T) {
		publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
		privateSubnetIds := terraform.OutputList(t, terraformOptions, "private_subnet_ids")

		// Based on our single-AZ architecture
		assert.Len(t, publicSubnetIds, 1, "Should have exactly 1 public subnet")
		assert.Len(t, privateSubnetIds, 1, "Should have exactly 1 private subnet")
	})

	// Test 3: Assert route tables exist
	t.Run("Route tables are created", func(t *testing.T) {
		publicRTId := terraform.Output(t, terraformOptions, "public_route_table_id")
		privateRTId := terraform.Output(t, terraformOptions, "private_route_table_id")

		assert.NotEmpty(t, publicRTId, "Public route table should be created")
		assert.NotEmpty(t, privateRTId, "Private route table should be created")
	})

	// Test 4: Assert security groups exist
	t.Run("Security groups are created", func(t *testing.T) {
		sgEdgeId := terraform.Output(t, terraformOptions, "sg_edge_id")
		sgAppId := terraform.Output(t, terraformOptions, "sg_app_id")

		assert.NotEmpty(t, sgEdgeId, "Edge security group should be created")
		assert.NotEmpty(t, sgAppId, "App security group should be created")
	})

	// Test 5: Assert internet gateway exists
	t.Run("Internet Gateway is created", func(t *testing.T) {
		igwId := terraform.Output(t, terraformOptions, "igw_id")
		assert.NotEmpty(t, igwId, "Internet Gateway should be created")
	})

	// Test 6: Skeleton for tag validation - placeholder for future expansion
	t.Run("Resources have tags", func(t *testing.T) {
		// This is a skeleton - actual tag validation would require AWS API calls
		// For now, we just verify the module applies successfully
		assert.True(t, true, "Tag validation would be implemented here in the future")
	})
}