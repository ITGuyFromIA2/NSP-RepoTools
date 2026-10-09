@{
    ClientSweep = @{
        ExcludePath = @()
        # The invented values the tests plant on purpose.
        Allow = @(
            'jane.doe@acmewidgets.com'
            'ops@acmewidgets.net'
            'acmewidgets.onmicrosoft.com'
            '\\fs01\finance'
            'C:\Users\jdoe'
            '52.10.20.30'
        )
        AllowPattern = @()
    }
}
