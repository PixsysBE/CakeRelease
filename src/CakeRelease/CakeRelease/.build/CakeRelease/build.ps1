param (
	[string]$securePasswordPath,
	[string]$vault,
	[string]$publishPackageToNugetSource="",
	[switch]$createGithubRelease,
	[switch]$autoBuild,
	[string]$csprojPath,
	[string]$nuspecFilePath,
	[switch]$verbose
)

$ErrorActionPreference = 'Stop'

$currentDirectory = Get-Location
$psBuildDirectory = $PSScriptRoot

# Import variables and scripts
# $functionsPath = Join-Path -Path $PSScriptRoot -ChildPath "./.build\CakeRelease\Powershell\variables.ps1"
$scriptsFolder = ".\Powershell\"
. (Join-Path -Path $PSScriptRoot -ChildPath "${scriptsFolder}functions.ps1")
. (Join-Path -Path $PSScriptRoot -ChildPath "${scriptsFolder}variables.ps1")

# Set location to psBuildDirectory because PSScriptRoot changed dur to the imports not in the same folder
Set-Location -LiteralPath $psBuildDirectory

#Making sure required variables exist
$securePasswordPath = Confirm-String-Parameter -param $securePasswordPath -prompt "Please enter the secure password path" 
$vault = Confirm-String-Parameter -param $vault -prompt "Please enter the vault name" 
# if ([string]::IsNullOrWhiteSpace($securePasswordPath)) {
# 	$securePasswordPath = read-host -Prompt "Please enter the secure password path" 
# }
# if ([string]::IsNullOrWhiteSpace($vault)) {
# 	$vault = read-host -Prompt "Please enter the vault name" 
# }

#unlock secret store to get secrets
$password = Import-CliXml -Path $securePasswordPath
Unlock-SecretStore -Password $password
$env:GH_TOKEN = Get-Secret -Name GH_TOKEN -Vault $vault -AsPlainText

#additional environments variables
$env:PUBLISH_PACKAGE_TO_NUGET_SOURCE = $publishPackageToNugetSource

# Get root path
# $rootPath = Resolve-Path (Join-Path -Path $psBuildDirectory -ChildPath $rootPathFolder)

# Get csproj path
# if ([string]::IsNullOrWhiteSpace($csprojPath)) {
#     $csprojFiles = Get-ChildItem -Path $rootPath -Recurse -Filter *.csproj | Where-Object { $_.Name -notmatch "\.Tests\.csproj$" }
#     # Check if only one csproj file exists
#     if ($csprojFiles.Count -ne 1)
#     {
#         Write-Host "Found $($csprojFiles.Count) csproj files. Please specify which csproj file to use"   
#         exit 1
#     }
#     else {
#         $csprojPath = $csprojFiles[0].FullName
#     }
# }


$nuspecProperties = Confirm-Nuspec-Properties -filePath $nuspecFilePath -verbose:$verbose

$csprojPath = Get-Csproj-Path -csprojPath $csprojPath
Copy-Git-Hooks -filePath $csprojPath -includePath $csprojTargetGitHooksCommitMsgPath -destinationFolder $csprojTargetGitHooksCommitMsgDestinationFolder -verbose:$verbose

#Ensure csproj has all the properties needed
# $bootstrapScript = Join-Path -Path $PSScriptRoot -ChildPath ".\Powershell\bootstrapRelease.ps1"
# $bootstrapScriptOutput = & $bootstrapScript -rootPath $rootPath -csprojPath $csprojPath

# if($bootstrapScriptOutput -eq 1) { exit 1 }


# --- [TEMP] Get nuspecFile path
# if ([string]::IsNullOrWhiteSpace($nuspecFilePath)) {

#     $nuspecPath = Join-Path -Path $rootPath -ChildPath ".\.build\CakeRelease\Package\release.nuspec"
#     if (Test-Path $nuspecPath) {
#         $nuspecFilePath = Resolve-Path $nuspecPath
#         Write-Host ".nuspec found: " $nuspecFilePath
#     }
#     else {
#         Write-Host "no .nuspec found "
#         exit 1
#     }
# }
# --- [TEMP] Get nuspecFile path

# $bootstrapScriptOutput = [PSCustomObject]@{
#     Id = 'CakeRelease'
#     Title = 'Cake Release'
#     Description = 'Cake Release description'
#     Authors = 'Sylvain Signore'
# }

#Create Semantic release config file based on parameters
# $semanticConfigPath = Join-Path -Path $PSScriptRoot -ChildPath ".\Semantic\Config\"
# $mainConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "main.js"
# $releaseConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "../.releaserc.js"

# $githubConfig = $null

# if($createGithubRelease.IsPresent)
# {
# 	$githubConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "github.js"
# 	$githubConfig = Get-Content -Path $githubConfigPath -Raw
# }

# $buildPath = ""
# if(-not $autoBuild.IsPresent)
# {
# 	$buildPath = "../"
# }

# $releaseConfig = (Get-Content -Path $mainConfigPath) -replace "{%GITHUB%}", $githubConfig
# Out-File -FilePath $releaseConfigPath -InputObject $releaseConfig -encoding UTF8

# #Cake build

# $cakePath = Join-Path -Path $PSScriptRoot -ChildPath ".\Cake"
Set-Location -LiteralPath $cakePath

dotnet tool restore
if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory	
	exit $LASTEXITCODE 
}

dotnet cake --projectName $nuspecProperties.Id --rootPath $rootPath --projectPath (Split-Path -Parent $csprojPath) --buildPath $buildPath --nuspecFilePath $nuspecFilePath

if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory
	exit $LASTEXITCODE 
}

Set-Location -LiteralPath $currentDirectory