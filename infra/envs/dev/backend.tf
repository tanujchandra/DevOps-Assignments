# Remote state for the DEV environment (separate bucket/key from prod).
# Create the bucket and lock table once, outside this stack.
# For offline review run:  terraform init -backend=false
terraform {
  backend "s3" {
    bucket         = "hotel-terraform-state-dev"
    key            = "hotel-app/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "hotel-terraform-locks-dev"
    encrypt        = true
  }
}
