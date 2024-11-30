[CmdletBinding()]
param (
	[string]$securePasswordPath,
	[string]$vault,
	[switch]$publishToNuget,
	[string]$publishToSource="",
	[string]$publishToSourceKey="",
	[switch]$createGithubRelease,
	[switch]$autoBuild,
	[string]$csprojPath,
	[string]$nuspecFilePath,

	[string]$launcherScriptDirectory=$PSScriptRoot # Directory containing launcher
)

$ErrorActionPreference = 'Stop'

# Directory where the script is called
$currentDirectory = Get-Location
# Directory containing cakerelease.ps1
$cakeReleaseScriptDirectory = $PSScriptRoot

Write-Verbose ("Welcome to cake release.ps1!")
Write-Verbose ("currentDirectory: $currentDirectory")
Write-Verbose ("launcherScriptDirectory: $launcherScriptDirectory")
Write-Verbose ("cakeReleaseScriptDirectory: $cakeReleaseScriptDirectory")

# Import variables and scripts
$scriptsFolder = ".\Powershell\"
. (Join-Path -Path $PSScriptRoot -ChildPath "${scriptsFolder}cakerelease.functions.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "${scriptsFolder}cakerelease.settings.ps1")

# Set location to cakeReleaseScriptDirectory because PSScriptRoot changed due to the imported scripts not in the same folder
Set-Location -LiteralPath $cakeReleaseScriptDirectory

# Ensure script required variables exist
$securePasswordPath = Confirm-String-Parameter -param $securePasswordPath -prompt "Please enter the secure password path" 
$vault = Confirm-String-Parameter -param $vault -prompt "Please enter the vault name" 

# Unlock secret store to get secrets
$password = Import-CliXml -Path $securePasswordPath
Unlock-SecretStore -Password $password
$env:GH_TOKEN = Get-Secret -Name GH_TOKEN -Vault $vault -AsPlainText

$env:NUGET_TOKEN = "notoken"
if($publishToNuget.IsPresent){
	$env:NUGET_TOKEN = Get-Secret -Name NUGET_TOKEN -Vault $vault -AsPlainText
	if([string]::IsNullOrWhiteSpace($env:NUGET_TOKEN)){
		Write-Host "Nuget Api key has not been defined, please update your vault with a NUGET_TOKEN secret"
		exit 1
	}
}

# Additional environments variables
$env:PUBLISH_PACKAGE_TO_NUGET_SOURCE = Format-With-Double-Backslash -string $publishToSource
$env:PUBLISH_PACKAGE_TO_NUGET_SOURCE_KEY = $publishToSourceKey

# Ensure .nuspec has all the properties needed
$nuspecProperties = Confirm-Nuspec-Properties -filePath $nuspecFilePath

# Ensure package.json has all the properties needed
$packageJsonProperties = Confirm-Package-Json-Properties -filePath $packageJsonPath -packageId $nuspecProperties.Id

# Git Hooks
Copy-Git-Hooks -filePath $csprojPath -includePath $csprojTargetGitHooksCommitMsgPath -destinationFolder $csprojTargetGitHooksCommitMsgDestinationFolder

# Ensure csproj has all the properties needed
Confirm-csproj-properties -filePath $csprojPath

# Create Semantic release config file based on parameters
$releaseConfig = (Get-Content -Path $mainConfigPath) -replace "{%GITHUB%}", $githubConfig
$releaseConfig = $releaseConfig -replace "{%NUGET%}", $nugetConfig
Confirm-Folder-Structure -path $semanticDirectory -filename $semanticReleaseRcFileName
Out-File -FilePath "$semanticDirectory\$semanticReleaseRcFileName" -InputObject $releaseConfig -encoding UTF8

# Cake build
Set-Location -LiteralPath $rootPath

dotnet tool restore
if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory	
	exit $LASTEXITCODE 
}

# Set-Location -LiteralPath $cakePath
Write-Verbose "build.cake path : $buildCakePath"
$packageSolution = $true
if((-not $createGithubRelease.IsPresent) -and (-not $publishToNuget.IsPresent) -and ([string]::IsNullOrWhiteSpace($publishToSource))){
	$packageSolution = $false
}

dotnet cake $buildCakePath --projectName $nuspecProperties.Id --rootPath $rootPath --projectPath (Split-Path -Parent $csprojPath) --buildPath $buildPath --nuspecFilePath $nuspecFilePath --changelogVersion $packageJsonProperties.changelogVersion --execVersion $packageJsonProperties.execVersion --gitVersion $packageJsonProperties.gitVersion --semanticReleaseVersion $packageJsonProperties.semanticReleaseVersion --packageSolution=$packageSolution

if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory
	exit $LASTEXITCODE 
}

Set-Location -LiteralPath $currentDirectory