terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.83.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-${var.environment}rg"
  location = var.location

  tags = {
    environment = var.environment
  }
}

resource "azurerm_storage_account" "storage" {
  name                     = "${var.prefix}${var.environment}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# resource "azurerm_storage_container" "cont" {
#   name                  = "com01"
#   storage_account_name  = azurerm_storage_account.storage.name
#   container_access_type = "private"
# }