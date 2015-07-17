function Get-CiscoInterfaces {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets Interface Configuration from Cisco Switch Config output.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$ShowSupportOutput
	)
	
	
}