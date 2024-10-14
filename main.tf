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
}

# todo - toremove
resource "azurerm_virtual_network" "test" {
  name                = "example-vnet"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.kv_rg.name
  address_space       = ["10.0.0.0/16"]
}
# todo - toremove
resource "azurerm_subnet" "test" {
  name                              = "private-endpoint-subnet"
  resource_group_name               = azurerm_resource_group.kv_rg.name
  virtual_network_name              = azurerm_virtual_network.test.name
  address_prefixes                  = ["10.0.1.0/24"]
  private_endpoint_network_policies = "Enabled"
}

module "pe" {
  source = "git::git@github.com:michalswi/pe.git?ref=main"

  location = local.location
  tags     = local.tags

  rg_name          = azurerm_resource_group.kv_rg.name
  source_vnet_id   = azurerm_virtual_network.test.id
  source_subnet_id = azurerm_subnet.test.id

  priv_conn_config = {
    name_prefix                      = "keyvault"
    private_connection_resource_id   = module.kv.key_vault_id
    private_connection_resource_name = module.kv.key_vault_name
    subresource_names                = ["vault"]
    private_dns_zone_name            = "privatelink.vaultcore.azure.net"
  }
}
