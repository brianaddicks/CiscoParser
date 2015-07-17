function Get-CiscoInterface {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets Interface Configuration from Cisco Switch Config output.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$ShowSupportOutput
	)
	
	$VerbosePrefix = "Get-CiscoInterface: "
	
	$IpRx = [regex] "(\d+\.){3}\d+"
	
	$TotalLines = $ShowSupportOutput.Count
	$i          = 0 
	$StopWatch  = [System.Diagnostics.Stopwatch]::StartNew() # used by Write-Progress so it doesn't slow the whole function down
	
	$NewDevice = New-Object -TypeName CiscoParser.Device
	
	:fileloop foreach ($line in $ShowSupportOutput) {
		$i++
		
		# Write progress bar, we're only updating every 1000ms, if we do it every line it takes forever
		
		if ($StopWatch.Elapsed.TotalMilliseconds -ge 1000) {
			$PercentComplete = [math]::truncate($i / $TotalLines * 100)
	        Write-Progress -Activity "Reading Support Output" -Status "$PercentComplete% $i/$TotalLines" -PercentComplete $PercentComplete
	        $StopWatch.Reset()
			$StopWatch.Start()
		}
		
		if ($line -eq "") { continue }
		
		###########################################################################################
		# New Access List
		
		$Regex = [regex] "^interface\ (?<name>.+)"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
			$NewInterface = New-Object -TypeName CiscoParser.Interface
			$NewInterface.Name = $Match.Groups['name'].Value
			
			$NewDevice.Interfaces += $NewInterface
		}
	}
}