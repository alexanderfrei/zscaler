terraform {

  backend "azurerm" {
  }

}

provider "azurerm" {
  features {}
}

/*
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
  required_version = ">= 0.13.7, < 2.0.0"
}
*/
## Example to store Terraform backend configurations in a file
#terraform {
#  required_providers {
#    azurerm = {
#      source  = "hashicorp/azurerm"
#      version = "~>3.0"
#    }
#  }
#  backend "azurerm" {
#      resource_group_name  = ""
#      storage_account_name = ""
#      container_name       = ""
#      key                  = ""
#  }

#}