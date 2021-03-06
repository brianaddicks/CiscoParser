[CmdletBinding()]
Param (
    [Parameter(Mandatory=$False,Position=0)]
	[switch]$PushToStrap
)

$VerbosePreference = "Continue"

if ($PushToStrap) {
    & ".\buildmodule.ps1" -PushToStrap
} else {
    & ".\buildmodule.ps1"
}

ipmo .\*.psd1

$ConfigDir = "\\vmware-host\Shared Folders\Dropbox\config dump"
$ConfigFile = $ConfigDir + '\co-6509c-mdf-rtr2.log'
$Config = gc $ConfigFile
	
#$global:test = Get-CiscoInterface $Config -Verbose 
$global:test = Get-CiscoAccessList $Config

foreach ($t in $test) {
	Write-host $t.Name
	$t.Rules | ft -Autosize
}

