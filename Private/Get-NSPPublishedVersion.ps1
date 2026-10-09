function Get-NSPPublishedVersion {
    # The newest version of a module in a PSResource repository, or $null when it isn't there.
    # Throws when the repository can't be asked (no PSResourceGet, no network).
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Repository
    )

    if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.PSResourceGet)) {
        throw 'Microsoft.PowerShell.PSResourceGet is required. Install it: Install-NSPModule -Name Microsoft.PowerShell.PSResourceGet'
    }
    Import-Module Microsoft.PowerShell.PSResourceGet -ErrorAction Stop
    try {
        $found = @(Find-PSResource -Name $Name -Repository $Repository -ErrorAction Stop)
    } catch {
        if ("$_" -match 'could not be found|not found') { return $null }
        throw
    }
    $found | ForEach-Object { [version]$_.Version } | Sort-Object -Descending | Select-Object -First 1
}
