provider "aws" {
  region = var.region

  # Plan-only mode: lets `terraform plan -refresh=false` run without any AWS account.
  # For a real deployment set  mock_credentials = false  and use real credentials.
  skip_credentials_validation = var.mock_credentials
  skip_requesting_account_id  = var.mock_credentials
  skip_metadata_api_check     = var.mock_credentials
  access_key                  = var.mock_credentials ? "mock" : null
  secret_key                  = var.mock_credentials ? "mock" : null

  default_tags {
    tags = local.tags
  }
}
