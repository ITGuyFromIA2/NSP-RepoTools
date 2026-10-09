@{
    IncludeDefaultRules = $true
    Severity = @('Error', 'Warning')
    ExcludeRules = @(
        # Test-Repo reports to the console by design.
        'PSAvoidUsingWriteHost'
    )
}
