param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Domain,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkingDirectory    
)

$scriptName = 'adds-config.ps1.log'
$logpath = $WorkingDirectory + '\\' + $scriptName

function Write-Log {
    param( [string] $msg)
    "$(Get-Date -Format FileDateTimeUniversal) : $msg" | Out-File -FilePath $logpath -Append -Force
}

function Exit-WithError {
    param( [string]$msg )
    Write-Log "There was an exception during the process, please review..."
    Write-Log $msg
    Exit 2
}

function Get-AdminCredential {
    # Get admin credentials
    Write-Log "Getting virtual machine tags from instance metadata service..."

    try {
        $tags = Invoke-RestMethod -Headers @{"Metadata" = "true" } -Method GET -Uri http://169.254.169.254/metadata/instance/compute/tagsList?api-version=2020-06-01 
    }
    catch {
        Exit-WithError $_
    }

    $kvname = ($tags | Where-Object { $_.name -eq 'keyvault' }).value

    if ( $null -eq $kvname ) {
        Exit-WithError "Unable to locate key vault name from virtual machine tags."
    }

    Write-Log "Using key vault name '$kvname'..."
    Write-Log "Getting managed identity token from instance metadata service..."

    try {
        $token = (Invoke-RestMethod -Headers @{"Metadata" = "true" } -Method GET -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2020-06-01&resource=https%3A%2F%2Fvault.azure.net').access_token
    }
    catch {
        Exit-WithError $_
    }

    Write-Log "Retrieving adminuser secret from key vault using managed identity..."
    $secretName = "adminuser"

    try {
        $secret = Invoke-RestMethod -Headers @{Authorization = "Bearer $token" } -Method GET -Uri "https://$kvname.vault.azure.net/secrets/$($secretName)?api-version=2016-10-01"
    }
    catch {
        Exit-WithError $_
    }

    $adminUser = $secret.Value
    Write-Log "Using adminuser '$adminUser'..."
    Write-Log "Retrieving adminpassword secret from key vault using managed identity..."
    $secretName = "adminpassword"

    try {
        $secret = Invoke-RestMethod -Headers @{Authorization = "Bearer $token" } -Method GET -Uri "https://$kvname.vault.azure.net/secrets/$($secretName)?api-version=2016-10-01"
    }
    catch {
        Exit-WithError $_
    }

    $adminPasswordSecure = ConvertTo-SecureString -String $secret.Value -AsPlainText -Force
    $adminPasswordSecure.MakeReadOnly()

    Write-Log "Using adminpassword '$('*' * $adminPasswordSecure.Length)'..."
    $adminCredential = New-Object System.Management.Automation.PSCredential ($adminUser, $adminPasswordSecure)

    return $adminCredential
}

$configData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
			PsDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
        }
    )
}

Configuration LabDomainConfig {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $AdminCredential,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Domain
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ActiveDirectoryDsc

    node 'localhost' {
        WindowsFeature 'AD-Domain-Services' {
            Name = 'AD-Domain-Services'
            Ensure = 'Present'
        }

        WindowsFeature 'RSAT-AD-PowerShell' {
            Name = 'RSAT-AD-PowerShell'
            Ensure = 'Present'
        }

        WindowsFeature 'RSAT-ADDS' {
            Name = 'RSAT-ADDS'
            Ensure = 'Present'
        }

        ADDomain 'LABDOMAIN' {
            DomainName = $Domain
            Credential = $AdminCredential
            SafemodeAdministratorPassword = $AdminCredential
            ForestMode = 'WinThreshold'
            DependsOn = '[WindowsFeature]AD-Domain-Services'
        }
    }
}          

# Start main
Write-Log "Running '$scriptName'..."
$adminCredential = Get-AdminCredential
Write-Log "Compiling basic domain configuration using domain '$Domain'..."

try {
    LabDomainConfig -AdminCredential $adminCredential -Domain $Domain -ConfigurationData $configData -OutputPath "$WorkingDirectory\LabDomainConfig"
}
catch {
    Exit-WithError $_
}

Write-Log "Starting DSC configuration..."
try {
    Start-DscConfiguration -Wait -Force -Verbose -Path "$WorkingDirectory\LabDomainConfig" -Credential $adminCredential
}
catch {
    Exit-WithError $_
}

Write-Log "Restarting computer..."
Restart-Computer
