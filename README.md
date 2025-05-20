# Terraform Remote Backend Bootstrapper

A zero-hassle script to provision secure and remote backend infrastructure for your Terraform projects using **Amazon S3** (for state storage) and **DynamoDB** (for state locking). 

Designed for teams and individuals who want to set up remote state management **in seconds**, without making errors or facing naming conflicts.

---

##    What This Solves

When working with Terraform in a team or CI/CD environment, it's critical to:
- Store your state file remotely
- Lock state files to prevent conflicts
- Secure your backend configuration

Manually setting this up is time-consuming and error-prone. This script handles everything.

---

## 🛠️ What It Does

Given an environment name (like `dev`, `prod`, or `test`) and an AWS region, the script:
-   Creates a **uniquely named S3 bucket** (with your environment and a hash to avoid collisions)
-   Enables **versioning** for state file recovery
-   Blocks all **public access** to the bucket
-   Creates a **DynamoDB table** for Terraform locking
-   Outputs a ready-to-use `backend.tf` block for Terraform

---

## Prerequisites

Before using this script, ensure you have:
- AWS CLI installed and configured with appropriate credentials
- Terraform installed
- AWS IAM permissions to:
  - Create S3 buckets
  - Modify bucket settings
  - Create DynamoDB tables

---

## Usage

```bash
chmod +x bootstrap.sh
./bootstrap.sh <your-environment-name> <aws-region>
````

Example:

```bash
./bootstrap.sh dev us-east-1
```

This will output a Terraform backend block like:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-dev-3f2a7b-destinyobs"
    key            = "env/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-dev-3f2a7b-destinyobs"
    encrypt        = true
  }
}
```

---

## backend.tf Template

If you prefer templating:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket-<env>-<unique-suffix>-destinyobs"
    key            = "env/<env>/terraform.tfstate"
    region         = "<your-region>"
    dynamodb_table = "terraform-lock-<env>-<unique-suffix>-destinyobs"
    encrypt        = true
  }
}
```

---

## Why Include `destinyobs`?

Every resource created includes a unique hash and the `destinyobs` suffix. This guarantees:

* No resource naming conflicts
* A signature of the script's creator (you’ll never forget who helped you)

---

## Author

**Destiny Obueh**
DevOps Engineer | iDeploy | iSecure | iSustain
GitHub: [@DestinyObs](https://github.com/DestinyObs)

---

## License

MIT License. Use, fork, and improve as you like.

````