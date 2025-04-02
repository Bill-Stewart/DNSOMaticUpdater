# DNSOMaticUpdater.ps1
# Written by Bill Stewart (bstewart AT iname.com)

#requires -version 5

<#
.SYNOPSIS
Updates the DNS-O-Matic service with the current external IP address.

.DESCRIPTION
Updates the DNS-O-Matic service with the current external IP address.

.PARAMETER GetExternalIPAddress
Gets the current external IP address.

.PARAMETER Setup
Performs initial setup: Configures network profile and credentials.

.PARAMETER SelectNetworkProfile
Updates the network profiles used for DNS-O-Matic updates based on a selection.

.PARAMETER SetCredentials
Updates the credentials used for connecting to the DNS-O-Matic service.

.PARAMETER Update
Updates the DNS-O-Matic service with the current external IP address. This parameter doesn't update the service if the IP address hasn't changed. To force an update, specify the -Force parameter.

.PARAMETER HostName
Specifies which hostname you want to update. (See the DNS-O-Matic API documentation for more information.)

.PARAMETER Force
Forces an update to the service even if the IP address hasn't changed.

.PARAMETER Log
Records activity to a log file for later inspection (useful for scheduling).

.NOTES
This script uses the following configuration files:

* NetworkProfile.txt - Network profiles to use for updates
* Credentials.dat - Credentials used by the service
* LastIP.txt - External IP address from the previous update

If NetworkProfile.txt is missing, the script will prompt for network profiles (-SelectNetworkProfile), which requires elevation ('Run as administrator').

If Credentials.dat is missing, the script will prompt for service credentials and create the file.
#>

[CmdletBinding(DefaultParameterSetName = "Update")]
param(
  [Parameter(ParameterSetName = "GetExternalIPAddress")]
  [Switch]
  $GetExternalIPAddress,

  [Parameter(ParameterSetName = "Setup")]
  [Switch]
  $Setup,

  [Parameter(ParameterSetName = "SelectNetworkProfile")]
  [Switch]
  $SelectNetworkProfile,

  [Parameter(ParameterSetName = "SetCredentials")]
  [Switch]
  $SetCredentials,

  [Parameter(ParameterSetName = "Update")]
  [Switch]
  $Update,

  [Parameter(ParameterSetName = "Update")]
  [String]
  $HostName,

  [Parameter(ParameterSetName = "Update")]
  [Switch]
  $Force,

  [Parameter(ParameterSetName = "GetExternalIPAddress")]
  [Parameter(ParameterSetName = "Update")]
  [Switch]
  $Log
)

$VersionTag  = "v0.0.2"
$ServiceName = "DNS-O-Matic"
$GetIPURL    = "http://myip.dnsomatic.com/"
$UpdateURL   = "https://updates.dnsomatic.com/nic/update/"
$Retries     = 3
$RetryDelay  = 3000     # milliseconds

$NetworkProfileFilePath = Join-Path $PSScriptRoot "NetworkProfile.txt"
$CredentialFilePath     = Join-Path $PSScriptRoot "Credentials.dat"
$LastIPFilePath         = Join-Path $PSScriptRoot "LastIP.txt"

# We need Get-NetConnectionProfile
try {
  Import-Module NetConnection -ErrorAction Stop
}
catch {
  Write-Error -Exception $_.Exception
  exit
}

function Get-NetworkProfile {
  Get-NetConnectionProfile | Select-Object -ExpandProperty Name
}

# Displays a list of network profiles, prompts for selection, and saves
# the names of the selected profiles to $NetworkProfilePath
function Select-NetworkProfile {
  $elevated = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if ( -not $elevated ) {
    Write-Error "This operation requires elevation ('Run as adminstrator'). Please restart PowerShell using the 'Run as administratror' option and try again." -Category PermissionDenied
    exit
  }
  $activeNetworkProfiles = Get-NetworkProfile
  if ( $null -eq $activeNetworkProfiles ) {
    Write-Error "Unable to determine current network profiles." -Category ObjectNotFound
    exit
  }
  $rootPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Profiles"
  $profiles = (Get-ChildItem $rootPath | ForEach-Object {
    Get-ItemProperty (Join-Path $rootPath (Split-Path $_.Name -Leaf)) |
      Select-Object -ExpandProperty ProfileName
  } | Sort-Object) -as [Array]
  if ( $profiles.Count -eq 0 ) {
    Write-Error "Unable to enumerate network profiles." -Category ObjectNotFound
    exit
  }
  Write-Host
  Write-Host "Please select network profiles for performing DNS updates. The script will"
  Write-Host "only perform updates when connected to the Internet using any of the selected"
  Write-Host "network profiles. -> indicates currently active network profiles."
  Write-Host
  Write-Host "   #    Network Profile"
  Write-Host "   ---  ---------------"
  $defaultIndexes = @()
  for ( $i = 0; $i -lt $profiles.Count; $i++ ) {
    if ( $activeNetworkProfiles -contains $profiles[$i] ) {
      $defaultIndexes += $i
      Write-Host ("-> {0,-4} {1}" -f ($i + 1),$profiles[$i])
    }
    else {
      Write-Host ("   {0,-4} {1}" -f ($i + 1),$profiles[$i])
    }
  }
  Write-Host
  while ( $true ) {
    $value = Read-Host ("Enter network profile numbers separated by spaces [Enter=active]" -f $profiles.Count)
    if ( $value.Trim() -eq "" ) {
      $choices = $defaultIndexes | ForEach-Object { $_ + 1 }
      break
    }
    $values = $value.Trim() -split '[ ,]'
    $choices = @()
    foreach ( $value in $values ) {
      if ( 1..$profiles.Count -notcontains $value ) {
        $choices = @()
        break
      }
      $choices += $value -as [Int]
    }
    if ( $choices.Count -gt 0 ) { break }
    Write-Host "Invalid selection."
  }
  $params = @{
    "FilePath"    = $NetworkProfileFilePath
    "Encoding"    = "ASCII"
    "Force"       = $true
    "ErrorAction" = "Stop"
  }
  $profileNames = $choices | ForEach-Object {
    $profiles[$_ - 1]
  }
  $profileNames | Out-File @params
  Write-Host ("Selected network profiles:{0}{1}" -f [Environment]::NewLine,
    ($profileNames -join [Environment]::NewLine))
}

function Get-RequestedNetworkProfile {
  $errorMsg = "Network profiles not specified or not valid. Please use the -SelectNetworkProfile parameter to select network profiles."
  if ( -not (Test-Path $NetworkProfileFilePath) ) {
    Write-Error $errorMsg -Category InvalidData
    return
  }
  $requestedNetworkProfiles = (Get-Content $NetworkProfileFilePath) -as [Array]
  if ( ($null -eq $requestedNetworkProfiles) -or ($requestedNetworkProfiles.Count -eq 0) ) {
    Write-Error $errorMsg -Category InvalidData
    return
  }
  return $requestedNetworkProfiles
}

function Compare-SecureString {
  param(
    [Security.SecureString]
    $secStr1,

    [Security.SecureString]
    $secStr2
  )
  try {
    $bSTR1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secStr1)
    $bSTR2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secStr2)
    $len1 = [Runtime.InteropServices.Marshal]::ReadInt32($bSTR1,-4)
    $len2 = [Runtime.InteropServices.Marshal]::ReadInt32($bSTR2,-4)
    if ( $len1 -ne $len2 ) {
      return $false
    }
    for ( $i = 0; $i -lt $len1; $i++ ) {
      $b1 = [Runtime.InteropServices.Marshal]::ReadByte($bSTR1,$i)
      $b2 = [Runtime.InteropServices.Marshal]::ReadByte($bSTR2,$i)
      if ( $b1 -ne $b2 ) {
        return $false
      }
    }
    return $true
  }
  finally {
    if ( $bSTR1 -ne [IntPtr]::Zero ) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bSTR1)
    }
    if ( $bSTR2 -ne [IntPtr]::Zero ) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bSTR2)
    }
  }
}

function Read-SecureString {
  do {
    $pass1 = Read-Host "Enter $ServiceName password" -AsSecureString
    $pass2 = Read-Host "Confirm $ServiceName password" -AsSecureString
    $match = Compare-SecureString $pass1 $pass2
    if ( -not $match ) {
      Write-Host "Passwords do not match"
    }
  }
  until ( $match )
  return $pass1
}

function ConvertTo-String {
  param(
    [Security.SecureString]
    $secString
  )
  try {
    $bSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secString)
    [Runtime.InteropServices.Marshal]::PtrToStringAuto($bSTR)
  }
  finally {
    if ( $bSTR -ne [IntPtr]::Zero ) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bSTR)
    }
  }
}

# Prompts for a username and password and saves them to $CredentialFilePath;
# line 1 = username, line 2 = random encryption key; 3 = encrypted password
function Set-CredentialFile {
  $params = @{
    "FilePath"    = $CredentialFilePath
    "Append"      = $false
    "Encoding"    = "ASCII"
    "Force"       = $true
    "ErrorAction" = "Stop"
  }
  do {
    $userName = Read-Host "Enter $ServiceName username"
  }
  until ( $userName )
  $userName | Out-File @params
  $rng = New-Object Security.Cryptography.RNGCryptoServiceProvider
  $randomBytes = New-Object Byte[] (32)
  $rng.GetBytes($randomBytes)
  $key = $randomBytes
  $params.Append = $true
  $key -join ' ' | Out-File @params
  ConvertFrom-SecureString (Read-SecureString) -Key $key | Out-File @params
}

function Get-ExternalIPAddress {
  $params = @{
    "Uri"             = $GetIPURL
    "UseBasicParsing" = $true
    "ErrorAction"     = "Stop"
  }
  for ( $i = 0; $i -lt $Retries; $i++ ) {
    try {
      $response = Invoke-WebRequest @params
      if ( $null -ne $response ) {
        return $response.Content
      }
    }
    catch {
      Write-Warning $_.Exception.Message
      Write-Warning "Retrying..."
    }
    Start-Sleep -Milliseconds $RetryDelay
  }
  Write-Error "Retry count exceeded; unable to get external IP address." -Category OpenError
}

# Converts the content of $CredentialFilePath to a base64-encoded http
# credential to use when requesting a DNS update
function Get-Base64Auth {
  $errorMsg = "Credentials not found or not valid. Please use the -SetCredentials parameter to specify credentials."
  if ( -not (Test-Path $CredentialFilePath) ) {
    Write-Error $errorMsg -Category InvalidData
    return
  }
  $content = (Get-Content $CredentialFilePath -ErrorAction SilentlyContinue) -as [Array]
  if ( (-not $content) -or ($content.Count -lt 3) ) {
    Write-Error $errorMsg -Category InvalidData
    return
  }
  $userName = $content | Select-Object -Index 0
  $key = ($content | Select-Object -Index 1) -split ' '
  $stdString = $content | Select-Object -Index 2
  if ( (-not $userName) -or (-not $key) -or (-not $stdString) ) {
    Write-Error $errorMsg -Category InvalidData
    return
  }
  $secString = ConvertTo-SecureString $stdString -Key $key -ErrorAction Stop
  $creds = "{0}:{1}" -f $userName,(ConvertTo-String $secString)
  [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($creds))
}

function Update-Service {
  param(
    [String]
    $base64Auth,

    [String]
    $lastIP,

    [String]
    $ipAddress,

    [String]
    $hostName
  )
  $updateParameters = ""
  if ( $hostName ) {
    $updateParameters += "hostname={0}&" -f $hostName
  }
  $updateParameters += "myip={0}" -f $ipAddress
  $headers = @{
    "User-Agent"    = "Bill Stewart - {0} - {1}" -f $MyInvocation.MyCommand.Name,$VersionTag
    "Get"           = $updateParameters
    "Authorization" = "Basic {0}" -f $base64Auth
  }
  $params = @{
    "Uri"             = $UpdateURL
    "Headers"         = $headers
    "UseBasicParsing" = $true
    "ErrorAction"     = "Stop"
  }
  for ( $i = 0; $i -lt $Retries; $i++ ) {
    try {
      $response = Invoke-WebRequest @params
      if ( $null -ne $response ) {
        # Update $LastIPFilePath if external IP has changed
        if ( $lastIP -ne $ipAddress ) {
          $params = @{
            "FilePath"    = $LastIPFilePath
            "Encoding"    = "ASCII"
            "Force"       = $true
            "ErrorAction" = "SilentlyContinue"
          }
          $IPAddress | Out-File @params
        }
        return $response.Content
      }
    }
    catch {
      Write-Warning $_.Exception.Message
      Write-Warning "Retrying..."
    }
    Start-Sleep -Milliseconds $RetryDelay
  }
  Write-Error "Retry count exceeded; unable to update service." -Category OpenError
}

$ParameterSetName = $PSCmdlet.ParameterSetName

if ( $ParameterSetName -eq "Setup" ) {
  Select-NetworkProfile
  Set-CredentialFile
  exit
}

if ( $ParameterSetName -eq "SelectNetworkProfile" ) {
  Select-NetworkProfile
  exit
}

if ( $ParameterSetName -eq "SetCredentials" ) {
  Set-CredentialFile
  exit
}

$LogFileName = "{0}.log" -f (Join-Path $PSScriptRoot `
  ([IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)))

if ( $ParameterSetName -eq "GetExternalIPAddress" ) {
  if ( $Log ) { Start-Transcript $LogFileName -ErrorAction Stop }
  Get-ExternalIPAddress
  if ( $Log ) { Stop-Transcript }
  exit
}

if ( $Log ) { Start-Transcript $LogFileName -ErrorAction Stop }

# Get requested network profile
$RequestedNetworkProfiles = Get-RequestedNetworkProfile
if ( -not $RequestedNetworkProfiles ) {
  if ( $Log ) { Stop-Transcript }
  exit
}

# Check if current network connection profiles matches any of requested
if ( $RequestedNetworkProfiles[0] -ne "<any>" ) {
  $CurrentNetworkProfiles = Get-NetworkProfile
  if ( -not $CurrentNetworkProfiles ) {
    Write-Error "Unable to determine current network profiles." -Category ObjectNotFound
    if ( $Log ) { Stop-Transcript }
    exit
  }
  $RequestedNetworkProfiles | ForEach-Object {
    if ( $CurrentNetworkProfiles -notcontains $_ ) {
      Write-Host ("Skipping update; current network profiles:{0}{1}" -f
        [Environment]::NewLine,($CurrentNetworkProfiles -join [Environment]::NewLine))
      if ( $Log ) { Stop-Transcript }
      exit
    }
  }
}

# Get external IP address
$IPAddress = Get-ExternalIPAddress
if ( -not $IPAddress ) {
  if ( $Log ) { Stop-Transcript }
  exit
}

# If not using -Force, check content of last IP file
if ( -not $Force ) {
  $LastIP = Get-Content $LastIPFilePath -ErrorAction SilentlyContinue
  if ( $LastIP -eq $IPAddress ) {
    Write-Host "Skipping update; External IP address still $IPAddress"
    if ( $Log ) { Stop-Transcript }
    exit
  }
}

# Retrieve credentials
$Base64Auth = Get-Base64Auth
if ( -not $Base64Auth ) {
  if ( $Log ) { Stop-Transcript }
  exit
}

# Update the service
Update-Service $Base64Auth $LastIP $IPAddress $HostName
if ( $Log ) { Stop-Transcript }
