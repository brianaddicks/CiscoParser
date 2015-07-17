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
$ConfigFile = $ConfigDir + '\co-6509c-mdf-rtr1.log'
	
