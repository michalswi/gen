provider "azurerm" {
  features {}
  # features {
  #   key_vault {
  #     purge_soft_delete_on_destroy    = true
  #     recover_soft_deleted_key_vaults = true
  #   }
  # }
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.4.0"
      # version = "~>4.0"
    }
  }
  # terraform version
  required_version = "~>1.5.0"
}
