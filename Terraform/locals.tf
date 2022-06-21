locals {
  identifier           = "octopus-001"
  virtual_machine_name = "vm-${local.identifier}"
  identity_id          = "/subscriptions/14de0224-a80e-4f73-93c7-8579b9012d60/resourceGroups/rg-paynenz-001/providers/Microsoft.ManagedIdentity/userAssignedIdentities/mi-octopus-001"
  storage_account_name = "paynenz"
}
