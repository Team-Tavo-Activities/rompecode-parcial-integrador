terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-caribeshop-tfstate"
    storage_account_name = "sttfstatecaribep9g438"
    container_name       = "tfstate"
    key                  = "caribeshop-prod.terraform.tfstate"
  }
}
