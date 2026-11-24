# Archivo: terraform/bootstrap/main.tf
# Propósito: Crear la cuenta de almacenamiento remota para guardar terraform.tfstate (Requisito S1)

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
}

provider "azurerm" {
  features {}
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "tfstate_rg" {
  name     = "rg-caribeshop-tfstate"
  location = "eastus2"

  tags = {
    Proyecto  = "CaribeShop"
    Proposito = "TerraformRemoteState"
  }
}

resource "azurerm_storage_account" "tfstate_sa" {
  name                            = "sttfstatecaribe${random_string.suffix.result}"
  resource_group_name             = azurerm_resource_group.tfstate_rg.name
  location                        = azurerm_resource_group.tfstate_rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate_cont" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate_sa.name
  container_access_type = "private"
}

output "backend_resource_group" {
  value = azurerm_resource_group.tfstate_rg.name
}

output "backend_storage_account" {
  value = azurerm_storage_account.tfstate_sa.name
}

output "backend_container" {
  value = azurerm_storage_container.tfstate_cont.name
}