# Creating a package and installing it using private winget rest repo
# Under heavy influence of the following instructions
# https://blogs.infosupport.com/adding-a-package-to-your-private-winget-restsource-feed-using-its-api/

### REVIEW ALL ASSIGNMENTS from line 1 to 35 and update as appropriate
# Then run the commands until line 100 in sequence to create a package in your private WinGet Rest
# (copy pasting them into your powershell console)

$packagename = 'vcredist'
$installerUrl = 'https://link.to/your/installer.exe'
$packageVersion = "1.0"

# msix
# msi
# appx
# exe
# inno
# nullsoft
# wix
# burn
# pwa
$installerType = 'msi'

# Open up your Azure Function App and look up the following:
# The REST endpoint base url: Open the Functions blade, click on the InformationGet function and click the “Get Function Url” button – the part before “/information?” is your endpoint base url.
# The host key: Open the App keys blade and copy the default host key (or generate a new one and use that), we’ll need it when modifying data (authorization keys are explained here).
$endpointBaseUrl = "https://changeme.azurewebsites.net/api/"
$hostKey = ""
$headers = @{ "x-functions-key" = $hostKey }

# This usually works when downloading files from the internet
# but f.x. files uploaded to azure storage accounts would need this field set and correctly formatted
# $fileName = (Invoke-WebRequest -Uri $installerUrl | Select-Object -ExpandProperty Headers)['Content-Disposition'] -split '; ' -match 'filename'.Split('=')[1].Trim('\"')
$fileName = "installer.exe"
Invoke-WebRequest -Uri $installerUrl -OutFile $fileName

$shasum = Get-FileHash -Algorithm SHA256 -Path $fileName
Remove-Item $fileName

# parse notepad packages yaml

$main = Get-Content "pkg.pkg.yaml" -Encoding UTF8 | ConvertFrom-Yaml -Ordered
$main.PackageIdentifier = "$packagename.$packagename"
$main.PackageVersion = $packageVersion

$localeEnglish = Get-Content "pkg.pkg.locale.en-US.yaml" -Encoding UTF8 | ConvertFrom-Yaml -Ordered
$localeEnglish.PackageIdentifier = "$packagename.$packagename"
$localeEnglish.PackageVersion = $packageVersion
$localeEnglish.Moniker = $packagename

$installer = Get-Content "pkg.pkg.installer.yaml" -Encoding UTF8 | ConvertFrom-Yaml -Ordered
$installer.PackageIdentifier = "$packagename.$packagename"
$installer.PackageVersion = $packageVersion
$installer.Commands.Clear()
$installer.Commands.Add($packagename)

# Adding to the /packages resource

$main | ConvertTo-Json -Depth 10 | Out-File "package.json" -Encoding utf8
Invoke-RestMethod -Uri "$endpointBaseUrl/packages" -Method Post -Headers $headers -InFile "package.json"

# Adding to the /versions resource

# Format difference: Tags are not allowed to have spaces in them.
[array]$localeEnglish.Tags = $localeEnglish.Tags | ForEach-Object { $_ -replace ' ', '' }
 
$version = [PSCustomObject] @{ PackageVersion = $main.PackageVersion; DefaultLocale = $localeEnglish }
$version | ConvertTo-Json -Depth 10 | Out-File "version.json" -Encoding utf8
 
Invoke-RestMethod -Uri "$endpointBaseUrl/packages/$($main.PackageIdentifier)/versions" -Method Post -Headers $headers -InFile "version.json"

# Adding to the /locales resource

# Format difference: The Publisher and PackageName properties are required.
$localeEnglish | ConvertTo-Json -Depth 10 | Out-File "locale.en-US.json" -Encoding utf8
Invoke-RestMethod -Uri "$endpointBaseUrl/packages/$($main.PackageIdentifier)/versions/$($main.PackageVersion)/locales" -Method Post -Headers $headers -InFile "locale.en-US.json"

# Adding to the /installers resource

# Add the installers. These need to be flattened, so take the Installers array as the base elements...
$installers = $installer.Installers
foreach ($elt in $installers) {
  #...and to each element, add all properties of the root Installer object (except for the Installers collection itself, of course).
  $installer.GetEnumerator() | Where-Object { $_.Key -ne "Installers" } | ForEach-Object { $elt.Add($_.Key, $_.Value) }
 
  # Format difference: Each installer needs a unique "InstallerIdentifier" property, so compose one like "x64.en-US.nullsoft"
  $installerIdentifier = "$($elt.Architecture).$($elt.InstallerLocale).$($elt.InstallerType)"
  $elt["InstallerIdentifier"] = $installerIdentifier

  $elt.InstallerType = $installerType
  $elt.InstallerUrl = $installerUrl
  $elt.InstallerSha256 = $shasum.Hash
 
  # Add it to the /installers collection
  $elt | ConvertTo-Json -Depth 10 | Out-File "installer.$installerIdentifier.json" -Encoding utf8
  Invoke-RestMethod -Uri "$endpointBaseUrl/packages/$($main.PackageIdentifier)/versions/$($main.PackageVersion)/installers" -Method Post -Headers $headers -InFile "installer.$installerIdentifier.json"
}

# -- DONE












# OPTIONAL - Backing up, altering, deleting and restoring manifests

$packageIdentifier = "$packagename.$packagename"
 
# Export the entire manifest (but leave out the top-level "Data" property)
$manifest = Invoke-RestMethod -Uri "$endpointBaseUrl/packageManifests/$packageIdentifier"
$manifest.Data | ConvertTo-Json -Depth 10 | Out-File "packageManifests.json" -Encoding utf8
 
# Update the manifest with the contents of the packageManifests.json file
Invoke-RestMethod -Uri "$endpointBaseUrl/packageManifests/$packageIdentifier" -Method Put -Headers $headers -InFile "packageManifests.json"
 
# Delete the manifest
Invoke-RestMethod -Uri "$endpointBaseUrl/packageManifests/$packageIdentifier" -Method Delete -Headers $headers
 
# Add a new manifest from a combined .json file:
Invoke-RestMethod -Uri "$endpointBaseUrl/packageManifests" -Method Post -Headers $headers -InFile "packageManifests.json"

# SANITY CHECK
Invoke-RestMethod -Uri "$endpointBaseUrl/information"

# USE 
## add source if missing
winget source add --name WinGetRest $endpointBaseUrl -t Microsoft.Rest
winget install $packagename --source WinGetRest

# Cleanup failed additions
Invoke-RestMethod -Uri "$endpointBaseUrl/packageManifests/$packageIdentifier" -Method Delete -Headers $headers
Invoke-RestMethod -Uri "$endpointBaseUrl/packages/$packagename.$packagename/versions/$packageVersion" -Method Delete -Headers $headers
Invoke-RestMethod -Uri "$endpointBaseUrl/packages/$packagename.$packagename" -Method Delete -Headers $headers
