# The PowerShell setup scripts included here were modified from the following release
# https://github.com/microsoft/winget-cli-restsource/releases/download/1.1.20230126/WinGet.RestSource-Winget.PowerShell.Source.zip
#
# iirc the files changed were 
#   Library\New-ARMParameterObject
#   Library\ARMTemplate\azurefunction.json
#   Library\ARMTemplate\asp.json
#

Connect-AzAccount # -SubscriptionId <optional subscription id>

$deploymentName = '<changeme>'
Set-Location $home\Downloads
Expand-Archive WinGet.RestSource-Winget.PowerShell.Source.zip
Set-Location WinGet.RestSource-Winget.PowerShell.Source
Import-Module .\Microsoft.WinGet.Source.psd1
New-WinGetSource `
  -Name $deploymentName `
  -ResourceGroup "WinGetPrivateSource" `
  -Region "westus" `
  -ImplementationPerformance "Demo" `
  -ShowConnectionInstructions

Install-Module -Name powershell-yaml

# Setup winget source 
$endpointBaseUrl = "https://$deploymentName.azurewebsites.net/api/"
winget source add --name WinGetRest $endpointBaseUrl -t Microsoft.Rest


# notes
# Az func prompts for manifestCacheEndpoint monitoringTenant monitoringRole monitoringMetricsAccount
# arm template shows these as values for winget
# The c# code references these for GCS / Geneva
#
# possible solution using env variables ?
# https://github.com/Azure/azure-linux-extensions/pull/1406/files

# Geneva or GCS
# https://github.com/microsoft/azure-pipelines-extensions/tree/master/Extensions/GenevaMonitor

# "manifestCacheEndpoint"
# "The endpoint where we expect manifests to be cached for this deployment ring."
