terraform {
  required_version = "1.5.0"
  # Configure the backend to stare the terraform state files
  # Credentials can be provided by using the TF_HTTP_USERNAME, and TF_HTTP_PASSWORD environment variables. (https://developer.hashicorp.com/terraform/language/settings/backends/http)
  backend "http" {
    address = "https://git.my-company.com/api/v4/projects/123/terraform/state/remote-terraform-state-files-123-cluster"
    lock_address = "https://git.my-company.com/api/v4/projects/123/terraform/state/remote-terraform-state-files-123-cluster/lock"
    unlock_address = "https://git.my-company.com/api/v4/projects/123/terraform/state/remote-terraform-state-files-123-cluster/lock"
    lock_method = "POST"
    unlock_method = "DELETE"
  }
}
