# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Install Octopus Server
choco install octopusdeploy -y

# Install the Octopus Deploy Service
$vaultName = 'keyvault-paynenz'
$octopusServerFilePath = "C:\Program Files\Octopus Deploy\Octopus\Octopus.Server.exe"
$octopusAdminPassword = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'octopus-admin-password' -AsPlainText
$sqlConnectionPassword = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'sqldb-octopus-001-password' -AsPlainText
$octopusLicenseKey = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'octopus-license-key-base64' -AsPlainText
$octopusConfigFilePath = "C:\Octopus\OctopusServer.config"
$octopusInstanceName = "OctopusServer"
$octopusServerName = "vm-octopus-001"

& $octopusServerFilePath create-instance --instance "$octopusInstanceName" --config "$octopusConfigFilePath" --serverNodeName "$octopusServerName"
& $octopusServerFilePath database --instance "$octopusInstanceName" --connectionString "Data Source=sql-paynenz-001.database.windows.net;Initial Catalog=sqldb-octopus-001;Integrated Security=False;User ID=chief;Password=$sqlConnectionPassword;Trust Server Certificate=True" --create --upgrade
& $octopusServerFilePath configure --instance "$octopusInstanceName" --webForceSSL "True" --webListenPrefixes "https://octopus.paynenz.com:443" --commsListenPort "10943" --usernamePasswordIsEnabled "True" --activeDirectoryIsEnabled "False"
& $octopusServerFilePath ssl-certificate --thumbprint="$sslCertThumbprint" --certificate-store="My"
& $octopusServerFilePath service --instance "$octopusInstanceName" --stop
& $octopusServerFilePath admin --instance "$octopusInstanceName" --username "chief" --email "stephen@paynenz.com" --password "$octopusAdminPassword"
& $octopusServerFilePath license --instance "$octopusInstanceName" --licenseBase64 "$octopusLicenseKey"
& $octopusServerFilePath service --instance "$octopusInstanceName" --install --reconfigure --start

# Open up port 443 for HTTPS traffic
New-NetFirewallRule -DisplayName "HTTPS (Port 443)" -Direction inbound -Profile Any -Action Allow -LocalPort 443 -Protocol TCP
