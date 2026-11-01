# Creates the MYX-VPN Android release keystore (PKCS12, RSA-4096, 100 years)
# and registers the signing secrets on the GitHub repo. The password is never printed.
param([string]$OutDir, [string]$Repo)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$ks = Join-Path $OutDir 'myx-release.jks'
if (Test-Path $ks) { throw "Keystore already exists: $ks (refusing to overwrite)" }

$bytes = New-Object byte[] 24
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$pw = ([Convert]::ToBase64String($bytes)) -replace '[+/=]', 'x'

$rsa = [Security.Cryptography.RSA]::Create(4096)
$dn = New-Object Security.Cryptography.X509Certificates.X500DistinguishedName 'CN=MYX-VPN, O=MYX-VPN'
$req = New-Object Security.Cryptography.X509Certificates.CertificateRequest $dn, $rsa, ([Security.Cryptography.HashAlgorithmName]::SHA256), ([Security.Cryptography.RSASignaturePadding]::Pkcs1)
$now = [DateTimeOffset]::UtcNow
$cert = $req.CreateSelfSigned($now.AddDays(-1), $now.AddYears(100))
$cert.FriendlyName = 'myx'
[IO.File]::WriteAllBytes($ks, $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $pw))

$sha = ([Security.Cryptography.SHA256]::Create().ComputeHash($cert.RawData) | ForEach-Object { $_.ToString('x2') }) -join ''
Set-Content (Join-Path $OutDir 'PASSWORD.txt') "Keystore + key password: $pw`r`nAlias: myx`r`nCert SHA-256: $sha`r`nKEEP THIS FOLDER BACKED UP. Losing it means users can no longer receive updates." -Encoding ascii

[Convert]::ToBase64String([IO.File]::ReadAllBytes($ks)) | gh secret set ANDROID_KEYSTORE_BASE64 --repo $Repo
$pw | gh secret set ANDROID_KEYSTORE_PASSWORD --repo $Repo
$pw | gh secret set ANDROID_KEY_PASSWORD --repo $Repo
'myx' | gh secret set ANDROID_KEY_ALIAS --repo $Repo
Write-Host "Keystore: $ks"
Write-Host "Cert SHA-256: $sha"
