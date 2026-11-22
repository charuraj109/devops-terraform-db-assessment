# Default: local state so `terraform init` works anywhere (no AWS needed).
# For real use, replace this file with backend-s3.tf.example (renamed to backend.tf).
terraform {
  backend "local" {
    path = "terraform.prod.tfstate"
  }
}
