################################################################################
# Make sure that Cloud Connector image terms have been accepted
################################################################################
resource "azurerm_marketplace_agreement" "zs_image_agreement" {
  offer     = var.acvm_marketplace_image_offer
  plan      = var.acvm_marketplace_image_sku
  publisher = var.acvm_marketplace_image_publisher
}

################################################################################
# Get Data Source Resource Group and DDoS Protection Plan
################################################################################

data "azurerm_resource_group" "<RG_ZSCALER_NAME>" {
  name = var.resource_group
}

data "azurerm_network_ddos_protection_plan" "<DDOS_PROTECTION_PLAN_NAME>" {
  name                = "<DDOS_PROTECTION_PLAN_NAME>"
  resource_group_name = "<RG_NAME_DDOS>"
}


################################################################################
# Get ZPA Provision Key from Key Vault
################################################################################
data "azurerm_key_vault" "kv01" {
  name         = var.azure_key_vault_name
  resource_group_name = var.azure_key_vault_resource_group_name
}

data "azurerm_key_vault_secret" "zpa_provision_key" {
  name         = var.azure_key_vault_zpa_provision_key_name
  key_vault_id = data.azurerm_key_vault.kv01.id
}

################################################################################
# Create User Data ATA to provison ZPA and ZPA key
################################################################################

locals {
  appuserdata = <<APPUSERDATA
#!/bin/bash
cat << EOL >> /etc/yum.repos.d/zscaler.repo
[zscaler]
name=Zscaler Private Access Repository
baseurl=https://yum.private.zscaler.com/yum/el9
enabled=1
gpgcheck=1
gpgkey=https://yum.private.zscaler.com/yum/el9/gpg
EOL
#Run a yum update to apply the latest patches
yum update -y
yum install zpa-connector -y 
#Create a file from the App Connector provisioning key created in the ZPA Admin Portal
#Make sure that the provisioning key is between double quotes
[ ! -d "/opt/zscaler/var" ] && mkdir -p /opt/zscaler/var/
echo "${data.azurerm_key_vault_secret.zpa_provision_key.value}" > /opt/zscaler/var/provision_key
chmod 644 /opt/zscaler/var/provision_key
#Start the App Connector service to enroll it in the ZPA cloud
systemctl start zpa-connector
#Wait for the App Connector to download latest build
sleep 60
#Stop and then start the App Connector for the latest build
systemctl stop zpa-connector
systemctl start zpa-connector
systemctl enable zpa-connector
APPUSERDATA
}

################################################################################
# Create NSG
################################################################################

resource "azurerm_network_security_group" "nsg-zpa-app-connector" {
  name                = "nsg-zpa-app-connector"
  location            = data.azurerm_resource_group.<RG_ZSCALER_NAME>.location
  resource_group_name = data.azurerm_resource_group.<RG_ZSCALER_NAME>.name
  tags                = var.global_tags
}

################################################################################
# Create Public IP
################################################################################

data "azurerm_resource_group" "<RG_NAME>" {
  name = "<RG_NAME>"
}

data "azurerm_public_ip_prefix" "<PIP_NAME>" {
  name                = "<PIP_NAME>"
  resource_group_name = data.azurerm_resource_group.<RG_NAME>.name
}

resource "azurerm_public_ip" "pip" {
  count               = var.ac_count
  name                = "pip-${var.name_prefix}-${count.index + 1}"
  resource_group_name = data.azurerm_resource_group.<RG_NAME>.name
  location            = data.azurerm_resource_group.<RG_NAME>.location
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
  public_ip_prefix_id = data.azurerm_public_ip_prefix.<PIP_NAME>.id
  tags                = var.global_tags
}

################################################################################
# Create VNet, Subnet and UDR
################################################################################

resource "azurerm_route_table" "udr-zpa-app-connector" {
  name                          = "udr-zpa-app-connector"
  location                      = data.azurerm_resource_group.<RG_ZSCALER_NAME>.location
  resource_group_name           = data.azurerm_resource_group.<RG_ZSCALER_NAME>.name
  bgp_route_propagation_enabled = true
  tags                          = var.global_tags

  route {
    name                    = "private-class-a"
    address_prefix          = "10.0.0.0/8"
    next_hop_type           = "VirtualAppliance"
    next_hop_in_ip_address  = var.azure_firewall_ip_west_europe
  }
  route {
    name                    = "private-class-b"
    address_prefix          = "172.16.0.0/12"
    next_hop_type           = "VirtualAppliance"
    next_hop_in_ip_address  = var.azure_firewall_ip_west_europe
  }
  route {
    name                    = "private-class-c"
    address_prefix          = "192.168.0.0/16"
    next_hop_type           = "VirtualAppliance"
    next_hop_in_ip_address  = var.azure_firewall_ip_west_europe
  }
}

resource "azurerm_virtual_network" "<RG_ZSCALER_NAME>-vnet" {
  name                = "<RG_ZSCALER_NAME>-vnet"
  location            = data.azurerm_resource_group.<RG_ZSCALER_NAME>.location
  resource_group_name = data.azurerm_resource_group.<RG_ZSCALER_NAME>.name
  address_space       = ["10.10.10.0/24"]
  dns_servers         = ["10.10.10.5"]

  subnet {
    name             = "zpa-app-connector"
    address_prefixes = ["10.10.10.0/27"]
    security_group   = azurerm_network_security_group.nsg-zpa-app-connector.id
  }

  ddos_protection_plan {
    enable         = true
    id             = data.azurerm_network_ddos_protection_plan.<DDOS_PROTECTION_PLAN_NAME>.id
  }

  tags = var.global_tags
}

data "azurerm_subnet" "zpa-app-connector" {
  name                 = "zpa-app-connector"
  virtual_network_name = azurerm_virtual_network.<RG_ZSCALER_NAME>-vnet.name
  resource_group_name  = data.azurerm_resource_group.<RG_ZSCALER_NAME>.name
}

resource "azurerm_subnet_route_table_association" "subnet-associate-zpa-app-connector" {
  subnet_id      = data.azurerm_subnet.zpa-app-connector.id
  route_table_id = azurerm_route_table.udr-zpa-app-connector.id
}


################################################################################
# Create App Connector Interface
################################################################################
resource "azurerm_network_interface" "ac_nic" {
  count               = var.ac_count
  name                = "${var.name_prefix}-ac-nic-${count.index + 1}"
  location            = data.azurerm_resource_group.<RG_ZSCALER_NAME>.location
  resource_group_name = data.azurerm_resource_group.<RG_ZSCALER_NAME>.name

  ip_configuration {
    name                          = "${var.name_prefix}-ac-nic-conf"
#    subnet_id                     = element(var.ac_subnet_id, count.index)
    subnet_id                     = data.azurerm_subnet.zpa-app-connector.id
    private_ip_address_allocation = "Dynamic"
    primary                       = true
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }

  tags = var.global_tags
}


################################################################################
# Create App Connector VM
################################################################################
resource "azurerm_linux_virtual_machine" "ac_vm" {
  count               = var.ac_count
  name                = "${var.name_prefix}-ac-${count.index + 1}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.<RG_ZSCALER_NAME>.name
  size                = var.acvm_instance_type
  availability_set_id = local.zones_supported == false ? azurerm_availability_set.ac_availability_set[0].id : null
  zone                = local.zones_supported ? element(var.zones, count.index) : null
  encryption_at_host_enabled  = true

  network_interface_ids = [
    azurerm_network_interface.ac_nic[count.index].id,
  ]

  computer_name  = "${var.name_prefix}-ac-${count.index + 1}"
  admin_username = var.ac_username
  #custom_data    = filebase64("custom_data.tpl")
  custom_data    = base64encode(local.appuserdata)

  admin_ssh_key {
    username   = var.ac_username
    public_key = var.ssh_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = var.acvm_image_publisher
    offer     = var.acvm_image_offer
    sku       = var.acvm_image_sku
    version   = var.acvm_image_version
  }

  tags = var.vm_tags

  depends_on = [
    azurerm_marketplace_agreement.zs_image_agreement,
  ]
}


################################################################################
# If AC zones are not manually defined, create availability set.
# If zones_enabled is set to true and the Azure region supports zones, this
# resource will not be created.
################################################################################
resource "azurerm_availability_set" "ac_availability_set" {
  count                       = local.zones_supported == false ? 1 : 0
  name                        = "${var.name_prefix}-ac-availability-set"
  location                    = var.location
  resource_group_name         = var.resource_group
  platform_fault_domain_count = local.max_fd_supported == true ? 3 : 2

  tags = var.global_tags
}
