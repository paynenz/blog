$vaultName = 'keyvault-paynenz'
$sslCertCAThumbprint = 'AC8243DFEBC7CE605C6C54B5132958ED458CC45C'
$sslCertThumbprint = 'D6BEDDBAC5EDAE93E72FD682D4B0831CA199065E'

# Allow the use of PowerShell gallery and install the required Azure modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module PowerShellGet -MinimumVersion 2.2.5 -SkipPublisherCheck -Force
Install-Module -Name Az.KeyVault -Repository PSGallery -Force

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install Octopus Server
choco install octopusdeploy -y

# Authenticate the Azure module
Connect-AzAccount -Identity

# Get the SSL cert from the Azure key vault and install it (including the required CA cert)
$vaultCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name 'cert-octopus-001-ssl'
$vaultCertSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $vaultCert.Name
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vaultCertSecret.SecretValue);
$plainTextVaultSecretValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr);
$vaultSecretValueBytes = [Convert]::FromBase64String($plainTextVaultSecretValue)
$certCollection = New-Object -TypeName 'System.Security.Cryptography.X509Certificates.X509Certificate2Collection'
$certCollection.Import($vaultSecretValueBytes, '', 'Exportable')

$certCollection | ForEach-Object {
    $tempCertFile = New-TemporaryFile
    
    if ($_.Thumbprint -eq $sslCertThumbprint) {
        Set-Content -Path $tempCertFile -Value $_.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx) -Encoding Byte
        Import-PfxCertificate -FilePath $tempCertFile -CertStoreLocation Cert:\LocalMachine\My
    }

    if ($_.Thumbprint -eq $sslCertCAThumbprint) {
        Set-Content -Path $tempCertFile -Value $_.GetRawCertData() -Encoding Byte
        Import-Certificate -FilePath $tempCertFile -CertStoreLocation Cert:\LocalMachine\Root
    }

    Remove-Item -Path $tempCertFile -Force
}

# Install the Octopus Deploy Service
$octopusServerFilePath = "C:\Program Files\Octopus Deploy\Octopus\Octopus.Server.exe"
$octopusAdminPassword = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'octopus-admin-password' -AsPlainText
$sqlConnectionPassword = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'sqldb-octopus-001-password' -AsPlainText
$octopusLicenseKey = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'octopus-license-key-base64' -AsPlainText
octopusStorageMasterKey = Get-AzKeyVaultSecret -VaultName $vaultName -Name 'octopus-storage-master-key' -AsPlainText
$octopusConfigFilePath = "C:\Octopus\OctopusServer.config"
$octopusInstanceName = "OctopusServer"
$octopusServerName = "vm-octopus-001"

& $octopusServerFilePath create-instance --instance "$octopusInstanceName" --config "$octopusConfigFilePath" --serverNodeName "$octopusServerName"
& $octopusServerFilePath database --instance "$octopusInstanceName" --connectionString "Data Source=sql-paynenz-001.database.windows.net;Initial Catalog=sqldb-octopus-001;Integrated Security=False;User ID=chief;Password=$sqlConnectionPassword;Trust Server Certificate=True" --create --upgrade
& $octopusServerFilePath configure --instance "$octopusInstanceName" --webForceSSL "True" --webListenPrefixes "https://octopus.paynenz.com:443" --commsListenPort "10943" --usernamePasswordIsEnabled "True" --activeDirectoryIsEnabled "False"
& $octopusServerFilePath ssl-certificate --thumbprint="D6BEDDBAC5EDAE93E72FD682D4B0831CA199065E" --certificate-store="My"
& $octopusServerFilePath service --instance "$octopusInstanceName" --stop
& $octopusServerFilePath admin --instance "$octopusInstanceName" --username "chief" --email "stephen@paynenz.com" --password "$octopusAdminPassword"
& $octopusServerFilePath license --instance "$octopusInstanceName" --licenseBase64 "$octopusLicenseKey"
& $octopusServerFilePath service --instance "$octopusInstanceName" --install --reconfigure --start

# Open up port 443 for HTTPS traffic
New-NetFirewallRule -DisplayName "HTTPS (Port 443)" -Direction inbound -Profile Any -Action Allow -LocalPort 443 -Protocol TCP
