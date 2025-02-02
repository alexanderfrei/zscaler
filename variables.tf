variable "name_prefix" {
  type        = string
  description = "A prefix to associate to all the AC VM module resources"
  default     = "zpa"
}

variable "global_tags" {
  type        = map(string)
  description = "Populate any custom user defined tags from a map"
  default     = {
    ManagedBy = "Terraform"
  }
}

variable "vm_tags" {
  type        = map(string)
  description = "Populate any custom user defined tags from a map"
  default     = {
    ManagedBy = "Terraform",
    special_vm = "ok"
  }
}

variable "resource_group" {
  type        = string
  description = "Main Resource Group Name"
  default     = ""
}

variable "location" {
  type        = string
  description = "App Connector Azure Region"
  default     = "westeurope"
}

variable "ac_username" {
  type        = string
  description = "Default App Connector admin/root username"
  default     = ""
}

variable "ssh_key" {
  type        = string
  description = "SSH Public Key for instances"
  default = ""
}

variable "acvm_instance_type" {
  type        = string
  description = "App Connector Image size"
  default     = "Standard_D4s_v3"
  validation {
    condition = (
      var.acvm_instance_type == "Standard_D4s_v3" ||
      var.acvm_instance_type == "Standard_F4s_v2"
    )
    error_message = "Input acvm_instance_type must be set to an approved vm size."
  }
}

variable "acvm_marketplace_image_offer" {
  type        = string
  description = "Azure Marketplace Zscaler App Connector Image Publisher"
  default     = "zscaler-private-access"
}

variable "acvm_marketplace_image_sku" {
  type        = string
  description = "Azure Marketplace Zscaler App Connector Image SKU"
  default     = "zpa-con-azure"
}

variable "acvm_marketplace_image_publisher" {
  type        = string
  description = "Azure App Connector Image Publisher"
  default     = "zscaler"
}

variable "acvm_image_publisher" {
  type        = string
  description = "Azure App Connector Image Publisher"
#  default     = "zscaler"
  default     = "RedHat"
}

variable "acvm_image_offer" {
  type        = string
  description = "Azure App Connector Image Offer"
#  default     = "zscaler-private-access"
  default     = "RHEL"
}

variable "acvm_image_sku" {
  type        = string
  description = "Azure App Connector Image SKU"
#  default     = "zpa-con-azure"
  default     = "9-lvm-gen2"
}

variable "acvm_image_version" {
  type        = string
  description = "Azure Marketplace App Connector Image Version"
  default     = "latest"
}

variable "ac_count" {
  type        = number
  description = "The number of App Connectors to deploy.  Validation assumes max for /24 subnet but could be smaller or larger as long as subnet can accommodate"
  default     = 1
  validation {
    condition     = var.ac_count >= 1 && var.ac_count <= 250
    error_message = "Input ac_count 0."
  }
}

variable "azure_firewall_ip_west_europe" {
  type        = string
  description = "Azure Firewall IP"
  default     = ""
}

variable "azure_key_vault_name" {
  type        = string
  description = "Azure Key Vault Name"
  default     = ""
}

variable "azure_key_vault_resource_group_name" {
  type        = string
  description = "Azure Key Vault Resource Group Name"
  default     = ""
}

variable "azure_key_vault_zpa_provision_key_name" {
  type        = string
  description = "Azure Key Vault ZPA Provision Key Name"
  default     = "zpa-provision-key"
}

# Validation to determine if Azure Region selected supports availabilty zones if desired
locals {
  az_supported_regions = ["australiaeast", "Australia East", "brazilsouth", "Brazil South", "canadacentral", "Canada Central", "centralindia", "Central India", "centralus", "Central US", "eastasia", "East Asia", "eastus", "East US", "francecentral", "France Central", "germanywestcentral", "Germany West Central", "japaneast", "Japan East", "koreacentral", "Korea Central", "northeurope", "North Europe", "norwayeast", "Norway East", "southafricanorth", "South Africa North", "southcentralus", "South Central US", "southeastasia", "Southeast Asia", "swedencentral", "Sweden Central", "uksouth", "UK South", "westeurope", "West Europe", "westus2", "West US 2", "westus3", "West US 3"]
  zones_supported = (
    contains(local.az_supported_regions, var.location) && var.zones_enabled == true
  )
}

variable "zones_enabled" {
  type        = bool
  description = "Determine whether to provision App Connector VMs explicitly in defined zones (if supported by the Azure region provided in the location variable). If left false, Azure will automatically choose a zone and module will create an availability set resource instead for VM fault tolerance"
  default     = true
}

variable "zones" {
  type        = list(string)
  description = "Specify which availability zone(s) to deploy VM resources in if zones_enabled variable is set to true"
  default     = ["1","2","3"]
  validation {
    condition = (
      !contains([for zones in var.zones : contains(["1", "2", "3"], zones)], false)
    )
    error_message = "Input zones variable must be a number 1-3."
  }
}

# Validation to determine if Azure Region selected supports 3 Fault Domain or just 2.
# This validation is only relevant if zones_enabled is set to false.
locals {
  max_fd_supported_regions = ["eastus", "East US", "eastus2", "East US 2", "westus", "West US", "centralus", "Central US", "northcentralus", "North Central US", "southcentralus", "South Central US", "canadacentral", "Canada Central", "northeurope", "North Europe", "westeurope", "West Europe"]
  max_fd_supported = (
    contains(local.max_fd_supported_regions, var.location) && var.zones_enabled == false
  )
}