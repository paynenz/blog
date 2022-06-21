function Install-Cert {
    param (
        [Parameter(Mandatory)]
        [Byte[]] $CertData,

        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.StoreName] $StoreName,

        [Parameter(Mandatory=$false)] 
        [switch] $GrantAccessToService
    )

    [Reflection.Assembly]::Load("System.Security, Version=2.0.0.0, Culture=Neutral, PublicKeyToken=b03f5f7f11d50a3a")

    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet

    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertData, '', $flags)

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($StoreName, [System.Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)

    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);

    $store.Add($cert);

    $store.Close();

    if ($GrantAccessToService.IsPresent) {
        $localSystemAccountSidString = 'S-1-5-18'
        $sid = New-Object System.Security.Principal.SecurityIdentifier($localSystemAccountSidString)
        $pkUniqueName = ([System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)).key.UniqueName
        $pkFile = Get-Item "$env:ProgramData\Microsoft\Crypto\RSA\MachineKeys\$pkUniqueName"
        $pkAcl = Get-Acl $pkFile
        $pkAcl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($sid, "Read", "Allow")))
        Set-Acl $pkFile.FullName $pkAcl
    }
}

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Refresh environment variables
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Install Octopus Server
choco install octopusdeploy -y

# Get the SSL cert from the Azure key vault and install it (including the required CA cert)
$vaultName = 'keyvault-paynenz'
$vaultCert = Get-AzKeyVaultCertificate -VaultName $vaultName -Name 'cert-octopus-001-ssl'
$vaultCertSecret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $vaultCert.Name
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vaultCertSecret.SecretValue);
$plainTextVaultSecretValue = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr);
$vaultSecretValueBytes = [Convert]::FromBase64String($plainTextVaultSecretValue)
$certCollection = New-Object -TypeName 'System.Security.Cryptography.X509Certificates.X509Certificate2Collection'
$certCollection.Import($vaultSecretValueBytes, '', 'Exportable')

$sslCertCAThumbprint = 'AC8243DFEBC7CE605C6C54B5132958ED458CC45C'
$sslCertThumbprint = 'D6BEDDBAC5EDAE93E72FD682D4B0831CA199065E'
$certCollection | ForEach-Object {
    if ($_.Thumbprint -eq $sslCertThumbprint) {
        $certData = $_.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx)
        Install-Cert -CertData $certData -StoreName 'My' -GrantAccessToService
    }

    if ($_.Thumbprint -eq $sslCertCAThumbprint) {
        $certData = $_.GetRawCertData()
        Install-Cert -CertData $certData -StoreName 'Root'
    }
}

# Install the Octopus Deploy Service
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
