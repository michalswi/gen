locals {
  location = "East US"
  tags = {
    Environment = "dev"
    Project     = "dev"
  }
}


resource "azurerm_resource_group" "kv_rg" {
  name     = "test"
  location = local.location
  tags     = local.tags
}

module "key_vault" {
  source = "git::git@github.com:michalswi/kv.git?ref=main"

  location = local.location
  rg_name  = azurerm_resource_group.kv_rg.name
  tags     = local.tags

  enable_logs              = false
  purge_protection_enabled = false
  retention_days           = 7
}


# VM related
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

# AG related

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

  location      = local.location
  backend_fqdns = ["myappservice.azurewebsites.net"]
  rg_name       = azurerm_resource_group.ag.name
  key_vault_id  = module.key_vault.key_vault_id

  enable_logs = false

  # if [] use 'default' cert
  # certificate_refs = ["ag-ssl-cert","test-ssl-cert"]

  agw_public_ip_id = azurerm_public_ip.pip.id

  agw_subnet_address_prefixes = azurerm_subnet.ag.address_prefixes
  agw_subnet_id               = azurerm_subnet.ag.id

  tags = local.tags
}
