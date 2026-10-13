# Remote state for the PROD environment (separate bucket/key/lock table from dev).
# Create the bucket and lock table once, outside this stack.
# For offline review run:  terraform init -backend=false
terraform {
  backend "s3" {
    bucket         = "hotel-terraform-state-prod"
    key            = "hotel-app/prod/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotel-terraform-locks-prod"
    encrypt        = true
  }
}
