terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# Auth comes from CLOUDFLARE_API_TOKEN in the environment (scripts/cloudflare.sh loads it
# from .env). Never put the token in a .tf or .tfvars file.
provider "cloudflare" {}
