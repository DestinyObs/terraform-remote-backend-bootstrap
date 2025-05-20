# backend.tf
# DestinyObs Universal Format – Never forget me

terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-<env>-<unique-suffix>-destinyobs"
    key            = "env/<env>/terraform.tfstate"
    region         = "<your-region>"
    dynamodb_table = "terraform-lock-<env>-<unique-suffix>-destinyobs"
    encrypt        = true
  }
}
