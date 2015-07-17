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