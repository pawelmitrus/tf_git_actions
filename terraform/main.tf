terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
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

resource "azurerm_databricks_workspace" "dbr_workspace" {
  name                        = "${var.prefix}-${var.environment}-dbr"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  sku                         = "premium"
  managed_resource_group_name = "${var.prefix}-${var.environment}-dbr-managed"

  public_network_access_enabled = true

  custom_parameters {
    no_public_ip        = true
    public_subnet_name  = azurerm_subnet.vnet_subnet_public.name
    private_subnet_name = azurerm_subnet.vnet_subnet_private.name
    virtual_network_id  = azurerm_virtual_network.vnet.id

    public_subnet_network_security_group_association_id  = azurerm_subnet_network_security_group_association.nsg_vnet_subnet_public.id
    private_subnet_network_security_group_association_id = azurerm_subnet_network_security_group_association.nsg_vnet_subnet_private.id
  }
}

resource "azurerm_storage_account" "storage" {
  name                     = "${var.prefix}${var.environment}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

data "azurerm_client_config" "client" {
}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.prefix}-${var.environment}-kv"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = data.azurerm_client_config.client.object_id

    key_permissions = [
      "Get",
    ]

    secret_permissions = [
      "Get",
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

resource "azurerm_storage_container" "container_bronze" {
  name                  = "bronze"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_container" "container_silver" {
  name                  = "silver"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}


resource "azuread_application" "aad_app_reg" {
  display_name = "${var.prefix}-${var.environment}-example-app"
  owners       = [data.azurerm_client_config.client.object_id]

}

resource "azuread_service_principal" "aad_service_principal" {
  client_id = azuread_application.aad_app_reg.client_id
}

resource "azuread_service_principal_password" "aad_service_principal_secret" {
  service_principal_id = azuread_service_principal.aad_service_principal.id
  end_date_relative    = "8760h"
}

resource "azurerm_key_vault_secret" "kv_secret" {
  name         = "service-principal-secret"
  value        = azuread_service_principal_password.aad_service_principal_secret.value
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_role_assignment" "rbac" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.client.object_id
}