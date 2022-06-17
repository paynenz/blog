$octopusAdminPassword = Get-AzKeyVaultSecret -VaultName keyvault-paynenz -Name octopus-admin-password -AsPlainText
$dir = New-Item -Path "c:\" -Name "temp" -ItemType Directory
New-Item -Path $dir -Name "terraform-test.txt" -ItemType "file" -Value "Octopus Admin Password: $octopusAdminPassword"