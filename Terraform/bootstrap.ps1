# Allow the use of PowerShell gallery and install the required Azure modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module PowerShellGet -MinimumVersion 2.2.5 -SkipPublisherCheck -Force
Install-Module -Name Az.Storage, Az.KeyVault -Repository PSGallery -Force

# Authenticate the Azure module
Connect-AzAccount -Identity

# Get the Azure blob storage key from the Azure key vault
$storageKey = Get-AzKeyVaultSecret -VaultName 'keyvault-paynenz' -Name 'paynenz-storage-key' -AsPlainText

# Get the install script from Azure Blob Storage and run it
$installScriptDir = 'c:\temp\'
$installScriptFileName = 'install_octopus.ps1'
$installScriptFilePath = Join-Path -Path $installScriptDir -ChildPath $installScriptFileName
$storageContext = New-AzStorageContext -StorageAccountName 'paynenz' -StorageAccountKey $storageKey
New-Item -Path $installScriptDir -ItemType 'Directory'
Get-AzStorageBlobContent -Context $storageContext -Blob $installScriptFileName -Container 'octopusstoragecontainer' -Destination $installScriptFilePath

# Run the install script
& $installScriptFilePath