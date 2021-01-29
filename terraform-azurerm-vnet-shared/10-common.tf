provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  # client_id       = "REPLACE-WITH-YOUR-CLIENT-ID"
  # client_secret   = "REPLACE-WITH-YOUR-CLIENT-SECRET"    
  # tenant_id       = "REPLACE-WITH-YOUR-TENANT-ID"
}

output "subscription_id" {
  value = var.subscription_id
}

provider "random" {}
 