terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                  = local.virtual_machine_name
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_B1s"
  admin_username        = var.octopus_vm_admin_username
  admin_password        = var.octopus_vm_admin_password
  computer_name         = local.virtual_machine_name
  network_interface_ids = [azurerm_network_interface.nic.id]
  timezone              = "New Zealand Standard Time"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-Server-Core-smalldisk"
    version   = "latest"
  }

  os_disk {
    name                 = "${local.virtual_machine_name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64
  }  

  identity {
    type = "UserAssigned"
    identity_ids = [ local.identity_id ]
  }
}

resource "azurerm_virtual_machine_extension" "install-ssl-certs" {
  name                 = "install-ssl-cert"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.KeyVault"
  type                 = "KeyVaultForWindows"
  type_handler_version = "1.0"

  settings = <<SETTINGS
  {
    "secretsManagementSettings": {
      "pollingIntervalInS": "3600",
      "certificateStoreName": "MY",
      "certificateStoreLocation": "LocalMachine",
      "observedCertificates": ["https://keyvault-paynenz.vault.azure.net/secrets/cert-octopus-001-ssl"]
    }
  }
  SETTINGS  
}

resource "azurerm_virtual_machine_extension" "install-octopus" {
  name                 = "install-octopus"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"

  protected_settings = <<SETTINGS
  {
     "commandToExecute": "powershell -encodedCommand ${textencodebase64(file("bootstrap.ps1"), "UTF-16LE")}"
  }
  SETTINGS

  depends_on = [
    azurerm_storage_blob.install-script
  ]
}
