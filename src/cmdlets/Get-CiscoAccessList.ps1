function Get-CiscoAccessList {
    [CmdletBinding()]
	<#
        .SYNOPSIS
            Gets Interface Configuration from Cisco Switch Config output.
	#>

	Param (
		[Parameter(Mandatory=$True,Position=0)]
		[array]$ShowSupportOutput
	)
	
	$VerbosePrefix = "Get-CiscoAccessList: "
	
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
		# New Extended Access List
		
		$Regex = [regex] "^ip\ access-list\ extended\ (.+)"
		$Match = HelperEvalRegex $Regex $line -ReturnGroupNum 1
		if ($Match) {
			$NewAccessList = New-Object -TypeName CiscoParser.AccessList
			$NewAccessList.Name = $Match
			$NewAccessList.Type = 'extended'
			
			$NewDevice.AccessLists += $NewAccessList
			$n = 1
		}
		
		if ($NewAccessList) {
			
			# Acl Rule
			$Regex = [regex] "(?x)
			                  ^\ 
							  (?<action>permit|deny)\ 
							  (?<protocol>\w+)
							  
							  #source
							  (\ (
							    (?<sourceip>any)
							  |
								(?<sourceip>$IpRx)\ (?<sourcemask>$IpRx)
							  ))
							  
							  #sourceport
							  (\ (
								eq\ (?<sourceport>\w+)
							  ))?
							  
							  #dest
							  (\ (
							    (?<destip>any)
							  |
								(?<destip>$IpRx)\ (?<destmask>$IpRx)
							  ))?
							  
							  #destport
							  (\ (
								eq\ (?<destport>\w+)
							  ))?
							"
			$Match = HelperEvalRegex $Regex $line
			if ($Match) {
				Write-Verbose "$VerbosePrefix $($Match.Value)"
				$NewAclRule = New-Object -TypeName CiscoParser.AclRule
				$NewAclRule.Number = $n
				$NewAclRule.Protocol           = $Match.Groups['protocol'].Value
				$NewAclRule.Action             = $Match.Groups['action'].Value
				$NewAclRule.SourceAddress      = $Match.Groups['sourceip'].Value
				$NewAclRule.DestinationAddress = $Match.Groups['destip'].Value
				$NewAclRule.SourcePort         = $Match.Groups['sourceport'].Value
				$NewAclRule.DestinationPort    = $Match.Groups['destport'].Value
				
				if ($Match.Groups['sourcemask'].Success) {
					$Mask = ConvertTo-MaskLength $Match.Groups['sourcemask'].Value
					$Mask = 32 - $Mask
					$NewAclRule.SourceAddress += "/$Mask"
				}
				
				if ($Match.Groups['destmask'].Success) {
					$Mask = ConvertTo-MaskLength $Match.Groups['destmask'].Value
					$Mask = 32 - $Mask
					$NewAclRule.DestinationAddress += "/$Mask"
				}
				
				$NewAccessList.Rules += $NewAclRule
				$n++
			}
			
			# Acl remarks
			if ($NewAclRule) {
				
				$EvalParams = @{}
				$EvalParams.StringToEval   = $line
				$EvalParams.Regex          = [regex] "^\ remark\ (.+)"
				$Eval                      = HelperEvalRegex @EvalParams -ReturnGroupNum 1
				if ($Eval) { $NewAclRule.Remark = $Eval }
			}
		}
		
		###########################################################################################
		# Basic Acls
		
		$Regex = [regex] "(?x)
						  ^access-list\ 
						  (?<name>\d+)\ 
						  (?<action>permit|deny)\ 
						  
						  (
						  #just a source ip
						  (?<sourceip>$IpRx)
						  |
						  #protocol
						  (?<protocol>\w+)
						  
						  #source
						  (\ (
						    (?<sourceip>any)|
							host\ (?<sourceip>$IpRx)|
							(?<sourceip>$IpRx)\ (?<sourcemask>$IpRx)
						  ))
						  
						  #sourceport
						  (\ (
							(?<sourceporttype>eq|gt)\ (?<sourceport>\w+)
						  ))?
						  
						  #destination
						  (\ (
						    (?<destip>any)|
							host\ (?<destip>$IpRx)|
							(?<destip>$IpRx)\ (?<destmask>$IpRx)
						  ))?
						  
						  #destport
						  (\ (
							(?<destporttype>eq|gt)\ (?<destport>\w+)
						  ))?
						  
						  )
		                 "
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
			Write-Verbose "$VerbosePrefix $($Match.Value)"
			$NewAclRule = New-Object -TypeName CiscoParser.AclRule
			
			# Check to see if we need to make a new ACL
			$AclName = $Match.Groups['name'].Value
			if ($NewAccessList.Name -eq $AclName) {
				$n++
			} else {
				$NewAccessList = New-Object -TypeName CiscoParser.AccessList
				$NewAccessList.Name = $AclName
				$NewAccessList.Type = 'basic'
				
				$NewDevice.AccessLists += $NewAccessList
				$n = 1
			}
			
			$NewAccessList.Rules += $NewAclRule
			
			$NewAclRule.Number             = $n
			$NewAclRule.Protocol           = $Match.Groups['protocol'].Value
			$NewAclRule.Action             = $Match.Groups['action'].Value
			$NewAclRule.SourceAddress      = $Match.Groups['sourceip'].Value
			$NewAclRule.DestinationAddress = $Match.Groups['destip'].Value
			
			
			# Check for port Type
			$SourcePortType = $Match.Groups['sourceporttype'].Value
			$DestPortType   = $Match.Groups['destporttype'].Value
			
			$SourcePort = $Match.Groups['sourceport'].Value
			$DestPort   = $Match.Groups['destport'].Value
			
			switch ($SourcePortType) {
				'gt' { $SourcePort = [string]([int]$SourcePort + 1) + "-65535" }
				default { }
			}
			
			switch ($DestPortType) {
				'gt' { $DestPort = [string]([int]$DestPort + 1) + "-65535" }
				default { }
			}
			
			$NewAclRule.SourcePort         = $SourcePort
			$NewAclRule.DestinationPort    = $DestPort
			
			if ($Match.Groups['sourcemask'].Success) {
				$Mask = ConvertTo-MaskLength $Match.Groups['sourcemask'].Value
				$Mask = 32 - $Mask
				$NewAclRule.SourceAddress += "/$Mask"
			}
			
			if ($Match.Groups['destmask'].Success) {
				$Mask = ConvertTo-MaskLength $Match.Groups['destmask'].Value
				$Mask = 32 - $Mask
				$NewAclRule.DestinationAddress += "/$Mask"
			}
		}	
	}
	
	return $NewDevice.AccessLists
}