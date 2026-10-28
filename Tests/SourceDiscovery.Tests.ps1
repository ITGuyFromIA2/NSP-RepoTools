# Read the discovery function without executing the runner, importing a module or installing dependencies.
BeforeAll {
    $runner = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools\Test-Repo.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($runner, [ref]$null, [ref]$null)
    $definition = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ModuleSourceFile'
    }, $true)
    if (-not $definition) { throw 'Get-ModuleSourceFile was not found.' }
    . ([scriptblock]::Create($definition.Extent.Text))
}

Describe 'Test-Repo source discovery' {
    It 'includes PowerShell files in nested literal paths and excludes documentation and Git metadata' {
        $script:repoRoot = Join-Path $TestDrive 'source tree [literal]'
        foreach ($name in @('root.ps1', 'nested\module.psm1', 'nested\manifest.psd1', 'project.git\keep.ps1', 'README.md', 'LICENSE', '.git\hooks\exclude.ps1')) {
            $path = Join-Path $script:repoRoot $name
            [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
            [IO.File]::WriteAllText($path, 'fixture')
        }
        @(Get-ModuleSourceFile | ForEach-Object Name | Sort-Object) |
            Should -Be @('keep.ps1', 'manifest.psd1', 'module.psm1', 'root.ps1')
    }
}
