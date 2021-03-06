###############################################################################
## Start Powershell Cmdlets
###############################################################################

###############################################################################
# Get-CiscoAccessList

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

###############################################################################
# Get-CiscoInterface

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
		# New Interface
		
		$Regex = [regex] "^interface\ (?<name>.+)"
		$Match = HelperEvalRegex $Regex $line
		if ($Match) {
			$NewInterface = New-Object -TypeName CiscoParser.Interface
			$NewInterface.Name = $Match.Groups['name'].Value
			
			$NewDevice.Interfaces += $NewInterface
		}
		
		if ($NewInterface) {
			# Eval Parameters for this section
			$EvalParams = @{}
			$EvalParams.StringToEval     = $line
			
			###########################################################################################
			# Bool Properties and Properties that need special processing
			
			# SwitchPort
			$EvalParams.Regex          = [regex] '^\ switchport$'
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) { $NewInterface.Switchport.Enabled = $true }
			
			# Trunk Mode
			$EvalParams.Regex          = [regex] '^\ switchport\ mode\ trunk$'
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) { $NewInterface.Switchport.Trunk.Enabled = $true }
			
			# Access Mode
			$EvalParams.Regex          = [regex] '^\ switchport\ mode\ access$'
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) { $NewInterface.Switchport.Access.Enabled = $true }
			
			# Shutdown
			$EvalParams.Regex          = [regex] '^\ shutdown$'
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) { $NewInterface.Shutdown = $true }
			
			# Trunk Allowed Vlans
			$EvalParams.Regex          = [regex] '^\ switchport\ trunk\ allowed\ vlan\ (.+)'
			$Eval                      = HelperEvalRegex @EvalParams -ReturnGroupNum 1
			if ($Eval) {
				$Eval = $Eval -replace 'add ',''
				foreach ($e in $Eval.Split(',')) {
					$DashSplit = $e.Split('-')
					if ($DashSplit.Count -gt 1) {
						for ($v = [int]($DashSplit[0]); $v -le [int]($DashSplit[1]); $v++) {
							$NewInterface.Switchport.Trunk.AllowedVlans += [int]$v
						}
					} else {
						$NewInterface.Switchport.Trunk.AllowedVlans += [int]$e
					}
				}
			}
			
			# Channel Group
			$EvalParams.Regex          = [regex] '^\ channel-group\ (?<group>\d+)\ mode\ (?<mode>.+)'
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) {
				$NewInterface.ChannelGroup.GroupNumber = $Eval.Groups['group'].Value
				$NewInterface.ChannelGroup.Mode        = $Eval.Groups['mode'].Value
			}
			
			# Ip Address
			$EvalParams.Regex          = [regex] '^\ ip\ address\ (?<ip>\d+\.\d+\.\d+\.\d+)\ (?<mask>\d+\.\d+\.\d+\.\d+)'
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) {
				$NewInterface.Layer3.IpAddress = $Eval.Groups['ip'].Value
				$NewInterface.Layer3.IpAddress += '/' + (ConvertTo-MaskLength $Eval.Groups['mask'].Value)
			}
			
			# Ip Helpers
			$EvalParams.Regex          = [regex] '^\ ip\ helper-address\ (.+)'
			$Eval                      = HelperEvalRegex @EvalParams -ReturnGroupNum 1
			if ($Eval) {
				$NewInterface.Layer3.HelperAddresses  += $Eval
			}
			
			# Access Group
			$EvalParams.Regex          = [regex] "^\ ip\ access-group\ (?<group>[^\ ]+)\ (?<dir>\w+)"
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) {
				Write-Verbose "$VerbosePrefix $($Eval.Value)"
				$NewInterface.Layer3.AccessGroup.Name      = $Eval.Groups['group'].Value
				$NewInterface.Layer3.AccessGroup.Direction = $Eval.Groups['dir'].Value
			}
			
			# Standby Ip
			$EvalParams.Regex          = [regex] "^\ standby\ (?<group>\d+)\ ip\ (?<ip>$IpRx)"
			$Eval                      = HelperEvalRegex @EvalParams
			if ($Eval) {
				$NewStandby           = New-Object -TypeName CiscoParser.Standby
				$NewStandby.Group     = $Eval.Groups['group'].Value
				$NewStandby.IpAddress = $Eval.Groups['ip'].Value
				
				$NewInterface.Layer3.StandbyGroups += $NewStandby
			}
			
			if ($NewStandby) {
				# Update eval Parameters for standby group
				$EvalParams.VariableToUpdate = ([REF]$NewStandby)
				$EvalParams.ReturnGroupNum   = 1
				$EvalParams.LoopName         = 'fileloop'
					
				# Description
				$EvalParams.ObjectProperty = "Priority"
				$EvalParams.Regex          = [regex] "^\ standby\ \d+\ priority\ (\d+)"
				$Eval                      = HelperEvalRegex @EvalParams
			}
			
			
			
			###########################################################################################
			# Regular Properties
			
			# Update eval Parameters for remaining matches
			$EvalParams.VariableToUpdate = ([REF]$NewInterface)
			$EvalParams.ReturnGroupNum   = 1
			$EvalParams.LoopName         = 'fileloop'
			
			###############################################
			# General Properties
			
			# Description
			$EvalParams.ObjectProperty = "Description"
			$EvalParams.Regex          = [regex] "^\ description\ (.+)"
			$Eval                      = HelperEvalRegex @EvalParams
			
			# Speed
			$EvalParams.ObjectProperty = "Speed"
			$EvalParams.Regex          = [regex] "^\ speed\ (\d+)"
			$Eval                      = HelperEvalRegex @EvalParams
			
			# Duplex
			$EvalParams.ObjectProperty = "Duplex"
			$EvalParams.Regex          = [regex] "^\ duplex\ (\w+)"
			$Eval                      = HelperEvalRegex @EvalParams
			
			###############################################
			# Trunk Attributes 
			
			# Trunk Native VLAN
			$EvalParams.VariableToUpdate = ([REF]$NewInterface.SwitchPort.Trunk)
			$EvalParams.ObjectProperty = "NativeVlan"
			$EvalParams.Regex          = [regex] "^\ switchport\ trunk\ native\ vlan\ (\d+)"
			$Eval                      = HelperEvalRegex @EvalParams
			
			# Trunk Encapsulation
			$EvalParams.VariableToUpdate = ([REF]$NewInterface.SwitchPort.Trunk)
			$EvalParams.ObjectProperty = "Encapsulation"
			$EvalParams.Regex          = [regex] "^\ switchport\ trunk\ encapsulation\ (.+)"
			$Eval                      = HelperEvalRegex @EvalParams
			
			# Access Vlan
			$EvalParams.VariableToUpdate = ([REF]$NewInterface.SwitchPort.Access)
			$EvalParams.ObjectProperty = "Vlan"
			$EvalParams.Regex          = [regex] "^\ switchport\ access\ vlan\ (\d+)"
			$Eval                      = HelperEvalRegex @EvalParams
		}
	}	
	return $NewDevice.Interfaces
}

###############################################################################
## Start Helper Functions
###############################################################################

###############################################################################
# HelperEvalRegex

function HelperEvalRegex {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0,ParameterSetName='RxString')]
		[String]$RegexString,
		
		[Parameter(Mandatory=$True,Position=0,ParameterSetName='Rx')]
		[regex]$Regex,
		
		[Parameter(Mandatory=$True,Position=1)]
		[string]$StringToEval,
		
		[Parameter(Mandatory=$False)]
		[string]$ReturnGroupName,
		
		[Parameter(Mandatory=$False)]
		[int]$ReturnGroupNumber,
		
		[Parameter(Mandatory=$False)]
		$VariableToUpdate,
		
		[Parameter(Mandatory=$False)]
		[string]$ObjectProperty,
		
		[Parameter(Mandatory=$False)]
		[string]$LoopName
	)
	
	$VerbosePrefix = "HelperEvalRegex: "
	
	if ($RegexString) {
		$Regex = [Regex] $RegexString
	}
	
	if ($ReturnGroupName) { $ReturnGroup = $ReturnGroupName }
	if ($ReturnGroupNumber) { $ReturnGroup = $ReturnGroupNumber }
	
	$Match = $Regex.Match($StringToEval)
	if ($Match.Success) {
		#Write-Verbose "$VerbosePrefix Matched: $($Match.Value)"
		if ($ReturnGroup) {
			#Write-Verbose "$VerbosePrefix ReturnGroup"
			switch ($ReturnGroup.Gettype().Name) {
				"Int32" {
					$ReturnValue = $Match.Groups[$ReturnGroup].Value.Trim()
				}
				"String" {
					$ReturnValue = $Match.Groups["$ReturnGroup"].Value.Trim()
				}
				default { Throw "ReturnGroup type invalid" }
			}
			if ($VariableToUpdate) {
				if ($VariableToUpdate.Value.$ObjectProperty) {
					#Property already set on Variable
					continue $LoopName
				} else {
					$VariableToUpdate.Value.$ObjectProperty = $ReturnValue
					Write-Verbose "$ObjectProperty`: $ReturnValue"
				}
				continue $LoopName
			} else {
				return $ReturnValue
			}
		} else {
			return $Match
		}
	} else {
		if ($ObjectToUpdate) {
			return
			# No Match
		} else {
			return $false
		}
	}
}

###############################################################################
## Export Cmdlets
###############################################################################

Export-ModuleMember *-*
