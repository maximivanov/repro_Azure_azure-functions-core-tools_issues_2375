terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Root module should specify the maximum provider version
      # The ~> operator is a convenient shorthand for allowing only patch releases within a specific minor release.
      version = "~> 2.26"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  project = "repro2375"
  location = "East US"
}

resource "azurerm_resource_group" "resource_group" {
  name = "${local.project}-resource-group"
  location = local.location
}

resource "azurerm_storage_account" "storage_account" {
  name = "${local.project}storage"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = local.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "${local.project}-app-service-plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = local.location
  kind                = "elastic"
  reserved            = true
  sku {
    tier = "ElasticPremium"
    size = "EP1"
  }
}

resource "azurerm_function_app" "function_app" {
  name                       = "${local.project}-function-app"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = local.location
  app_service_plan_id        = azurerm_app_service_plan.app_service_plan.id
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"       = "",
    # "WEBSITES_ENABLE_APP_SERVICE_STORAGE"   = true,
    "FUNCTIONS_WORKER_RUNTIME"              = "node",
  }
  os_type = "linux"
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  version                    = "~3"
  
  # this is to avoid config drift being reported on app setting change after code deploy
  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}
