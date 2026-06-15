# Infrastructure as code

VAST Data Platform supports Terraform using the following provider:

- https://registry.terraform.io/providers/vast-data/vastdata/latest/docs

Below are some example Terraform scripts for configuring a newly installed cluster:

## provider.tf


```terraform
# provider.tf

terraform {
  required_providers {
    vastdata = {
      source  = "vast-data/vastdata"
      version = ">= 1.6.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "vastdata" {
  # VAST Management Server (VMS) endpoint and credentials.
  # These are sourced from the variables defined in variables.tf.
  # It is recommended to set these using environment variables for security.
  # Example: export TF_VAR_vast_user='admin'

  host            = var.vast_endpoint
  username        = var.vast_user
  password        = var.vast_password

  # Set to true if your VMS uses a self-signed certificate
  skip_ssl_verify = true
}

provider "local" {
  # This provider is used to write connection details to a local file.
}
```

## variables.tf

```terraform
# variables.tf

variable "vast_endpoint" {
  type        = string
  description = "The IP address or hostname of the VAST Management Server (VMS)."
  default     = "10.95.2.126"
}

variable "vast_user" {
  type        = string
  description = "The username for VMS authentication."
  default     = "admin"
  sensitive   = true
}

variable "vast_password" {
  type        = string
  description = "The password for VMS authentication."
  default     = "123456"
  sensitive   = true
}

variable "database_owner" {
  type        = string
  description = "The name of the user to be created as the database owner."
  default     = "demo-owner"
}

variable "database_name" {
  type        = string
  description = "The name of the database (and bucket)."
  default     = "demo-database"
}

variable "database_view_path" {
  type        = string
  description = "The path for the new view."
  default     = "/demo-view"
}
```
## outputs.tf

```terraform
# outputs.tf

output "s3_access_key" {
  description = "The S3 access key for the demo user."
  value       = vastdata_user_key.demo_key.access_key
}

output "s3_secret_key" {
  description = "The S3 secret key for the demo user."
  value       = vastdata_user_key.demo_key.secret_key
  sensitive   = true
}

output "connection_details_file" {
  description = "Path to the file containing connection details."
  value       = local_file.connection_details.filename
}
```

## main.tf

```terraform
# main.tf

resource "vastdata_vip_pool" "demo_pool" {
  name        = "demo-vip-pool"
  subnet_cidr = 24
  role        = "PROTOCOLS"

  ip_ranges {
    start_ip = "11.0.0.2"
    end_ip   = "11.0.0.3"
  }
}

resource "vastdata_user" "demo_user" {
  name                = var.database_owner
  uid                 = 555
  allow_create_bucket = true
  s3_superuser        = true
}

resource "vastdata_user_key" "demo_key" {
  user_id = vastdata_user.demo_user.id
}

resource "vastdata_view" "demo_view" {
  path         = var.database_view_path
  protocols    = ["S3", "DATABASE"]
  bucket       = var.database_name
  bucket_owner = vastdata_user.demo_user.name
  create_dir   = true
  policy_id    = 3

  depends_on = [vastdata_vip_pool.demo_pool]
}


resource "local_file" "connection_details" {
  content = <<-EOT
    ENDPOINT=http://${var.vast_endpoint}:9090
    DATABASE_OWNER=${var.database_owner}
    DATABASE_VIEW_PATH=${var.database_view_path}
    DATABASE_NAME=${var.database_name}
    ACCESS_KEY=${vastdata_user_key.demo_key.access_key}
    SECRET_KEY=${vastdata_user_key.demo_key.secret_key}
  EOT

  filename = "${path.cwd}/connection_details.txt"
}
```