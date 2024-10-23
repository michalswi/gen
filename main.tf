locals {
  location = "East US"
  tags = {
    Environment = "dev"
    Project     = "dev"
  }
}


## LA related

module "log_analytics_name" {
  source        = "git::git@github.com:michalswi/caf.git?ref=main"
  resource_type = "azurerm_log_analytics_workspace"

  # org_id        = var.org_id
  # region        = var.region
  # function      = var.function
  # environment   = var.environment
  index = "001"
}

resource "azurerm_resource_group" "rg_la" {
  name     = "testla"
  location = local.location
  tags     = local.tags
}

module "log_analytics" {
  source = "git::git@github.com:michalswi/la.git?ref=main"

  name = module.log_analytics_name.caf_name

  location          = local.location
  rg_name           = azurerm_resource_group.rg_la.name
  sku               = "PerGB2018"
  retention_in_days = 30
}


## kv related

module "key_vault_name" {
  source = "git::git@github.com:michalswi/caf.git?ref=main"

  # org_id        = var.org_id
  # region        = var.region
  # function      = var.function
  # environment   = var.environment
  index         = "001"
  resource_type = "azurerm_key_vault"
}

resource "azurerm_resource_group" "rg_kv" {
  name     = "test"
  location = local.location
  tags     = local.tags
}

module "key_vault" {
  source = "git::git@github.com:michalswi/kv.git?ref=main"

  location = local.location
  rg_name  = azurerm_resource_group.rg_kv.name
  name     = module.key_vault_name.caf_name

  tags = local.tags

  # enable_logs = false
  # 'enable_logs' by default 'true'
  log_analytics_workspace_id = module.log_analytics.log_analytics_workspace_id

  purge_protection_enabled = false
  retention_days           = 7
}


## AG related

module "application_gateway_name" {
  source        = "git::git@github.com:michalswi/caf.git?ref=main"
  resource_type = "azurerm_application_gateway"

  # org_id        = var.org_id
  # region        = var.region
  # function      = var.function
  # environment   = var.environment
  index = "001"
}

resource "azurerm_resource_group" "ag" {
  name     = "ag-rg"
  location = local.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "ag" {
  name                = "ag-vnet"
  location            = local.location
  resource_group_name = azurerm_resource_group.ag.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "ag" {
  name                              = "ag-subnet"
  resource_group_name               = azurerm_resource_group.ag.name
  virtual_network_name              = azurerm_virtual_network.ag.name
  address_prefixes                  = ["10.20.1.0/24"]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_public_ip" "pip" {
  name                = "ag-pip"
  resource_group_name = azurerm_resource_group.ag.name
  location            = local.location
  sku                 = "Standard"
  sku_tier            = "Regional"
  allocation_method   = "Static"
  ip_version          = "IPv4"
}

module "azure_app_gateway" {
  source = "git::git@github.com:michalswi/ag.git?ref=main"

  name          = module.application_gateway_name.caf_name
  location      = local.location
  backend_fqdns = ["myappservice.azurewebsites.net"]
  rg_name       = azurerm_resource_group.ag.name
  key_vault_id  = module.key_vault.key_vault_id

  # enable_logs = false
  log_analytics_workspace_id = module.log_analytics.log_analytics_workspace_id

  # if [] use 'default' cert
  # certificate_refs = ["ag-ssl-cert","test-ssl-cert"]

  agw_public_ip_id = azurerm_public_ip.pip.id

  agw_subnet_address_prefixes = azurerm_subnet.ag.address_prefixes
  agw_subnet_id               = azurerm_subnet.ag.id

  tags = local.tags
}


## SA related

module "storage_account_name" {
  source        = "git::git@github.com:michalswi/caf.git?ref=main"
  resource_type = "azurerm_storage_account"

  # org_id        = var.org_id
  # region        = var.region
  # function      = var.function
  # environment   = var.environment
  index = "001"
}

resource "azurerm_resource_group" "sa" {
  name     = "sa-rg"
  location = local.location
  tags     = local.tags
}

module "storage_account" {
  source = "git::git@github.com:michalswi/sa.git?ref=main"

  name     = module.storage_account_name.caf_name
  location = local.location
  rg_name  = azurerm_resource_group.sa.name

  enable_logs = false
  # OR
  # log_analytics_workspace_id = module.log_analytics.log_analytics_workspace_id

  # todo - pass sp_id
  # service_principal_id = ""
  # enable_sp = true
  # OR
  enable_sp = false # by default false

  tags = local.tags
}


## VM related
# resource "azurerm_resource_group" "vm_rg" {
#   name     = "testvm"
#   location = local.location
#   tags     = local.tags
# }

# resource "azurerm_virtual_network" "vmtest" {
#   name                = "vm-vnet"
#   location            = local.location
#   resource_group_name = azurerm_resource_group.vm_rg.name
#   address_space       = ["10.10.0.0/16"]
# }

# resource "azurerm_subnet" "vmtest" {
#   name                              = "vm-subnet"
#   resource_group_name               = azurerm_resource_group.vm_rg.name
#   virtual_network_name              = azurerm_virtual_network.vmtest.name
#   address_prefixes                  = ["10.10.1.0/24"]
#   private_endpoint_network_policies = "Enabled"
# }

# module "pe" {
#   source = "git::git@github.com:michalswi/pe.git?ref=main"

#   location = local.location
#   tags     = local.tags

#   rg_name          = azurerm_resource_group.vm_rg.name
#   source_vnet_id   = azurerm_virtual_network.vmtest.id
#   source_subnet_id = azurerm_subnet.vmtest.id

#   priv_conn_config = {
#     name_prefix                      = "keyvault"
#     private_connection_resource_id   = module.key_vault.key_vault_id
#     private_connection_resource_name = module.key_vault.key_vault_name
#     subresource_names                = ["vault"]
#     private_dns_zone_name            = "privatelink.vaultcore.azure.net"
#   }
# }

# module "vm" {
#   source = "git::git@github.com:michalswi/vm.git?ref=main"

#   location = local.location
#   tags     = local.tags

#   rg_name          = azurerm_resource_group.vm_rg.name
#   source_subnet_id = azurerm_subnet.vmtest.id
#   source_vnet_name = azurerm_virtual_network.vmtest.name

#   key_vault_id = module.key_vault.key_vault_id

#   ip_whitelist = ["<ip>"]
# }
