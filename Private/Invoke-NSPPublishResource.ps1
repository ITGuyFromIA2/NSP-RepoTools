function Invoke-NSPPublishResource {
    # Publishes a staged module folder with PSResourceGet. The legacy PowerShellGet path is not
    # used: 1.0.0.1 reports success on a failed publish, and 2.2.5 fails against the installed
    # PackageManagement (both seen live 2026-09). The API key comes from Get-NSPSecret.
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$SecretName
    )

    if (-not (Get-Command Get-NSPSecret -ErrorAction SilentlyContinue)) {
        $sibling = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '..\NSP-Bootstrap\NSP.Bootstrap.psd1'
        if (Get-Module -ListAvailable -Name NSP.Bootstrap) { Import-Module NSP.Bootstrap -ErrorAction Stop }
        elseif (Test-Path -LiteralPath $sibling) { Import-Module $sibling -ErrorAction Stop }
        else { throw 'NSP.Bootstrap (Get-NSPSecret) is required for the API key: Install-Module NSP.Bootstrap' }
    }
    $apiKey = Get-NSPSecret -Name $SecretName -AsPlainText
    if ([string]::IsNullOrWhiteSpace($apiKey)) { throw "Secret '$SecretName' is empty or missing." }

    Import-Module Microsoft.PowerShell.PSResourceGet -ErrorAction Stop
    Publish-PSResource -Path $Path -ApiKey $apiKey -Repository $Repository -ErrorAction Stop
}
