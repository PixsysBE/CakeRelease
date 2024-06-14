param (
	[string]$securePasswordPath,
	[string]$vault,
	[string]$publishPackageToNugetSource="",
	[switch]$createGithubRelease,
	[switch]$autoBuild,
	[string]$csprojPath
)

$ErrorActionPreference = 'Stop'

$currentDirectory = Get-Location

Set-Location -LiteralPath $PSScriptRoot

$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

#making sure required variables exist
if ($securePasswordPath -eq $null) {
	$securePasswordPath = read-host -Prompt "Please enter the secure password path" 
}
if ($vault -eq $null) {
	$vault = read-host -Prompt "Please enter the vault name" 
}

#unlock secret store to get secrets
$password = Import-CliXml -Path $securePasswordPath
Unlock-SecretStore -Password $password
$env:GH_TOKEN = Get-Secret -Name GH_TOKEN -Vault $vault -AsPlainText

#additional environments variables
$env:PUBLISH_PACKAGE_TO_NUGET_SOURCE = $publishPackageToNugetSource

# Get root path
$rootPath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "../..")

# Get csproj path
if ([string]::IsNullOrWhiteSpace($csprojPath)) {
    $csprojFiles = Get-ChildItem -Path $rootPath -Recurse -Filter *.csproj | Where-Object { $_.Name -notmatch "\.Tests\.csproj$" }
    # Check if only one csproj file exists
    if ($csprojFiles.Count -ne 1)
    {
        Write-Host "Found $($csprojFiles.Count) csproj files. Please specify which csproj file to use"   
        exit 1
    }
    else {
        $csprojPath = $csprojFiles[0].FullName
    }
}

#Ensure csproj has all the properties needed
$bootstrapScript = Join-Path -Path $PSScriptRoot -ChildPath ".\Powershell\bootstrapRelease.ps1"
$bootstrapScriptOutput = & $bootstrapScript -rootPath $rootPath -csprojPath $csprojPath

if($bootstrapScriptOutput -eq 1) { exit 1 }

#Create Semantic release config file based on parameters
$semanticConfigPath = Join-Path -Path $PSScriptRoot -ChildPath ".\Semantic\Config\"
$mainConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "main.js"
$releaseConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "../.releaserc.js"

$githubConfig = $null

if($createGithubRelease.IsPresent)
{
	$githubConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "github.js"
	$githubConfig = Get-Content -Path $githubConfigPath -Raw
}

$buildPath = ""
if(-not $autoBuild.IsPresent)
{
	$buildPath = "../"
}

$releaseConfig = (Get-Content -Path $mainConfigPath) -replace "{%GITHUB%}", $githubConfig
Out-File -FilePath $releaseConfigPath -InputObject $releaseConfig -encoding UTF8

#Cake build

$cakePath = Join-Path -Path $PSScriptRoot -ChildPath ".\Cake"
Set-Location -LiteralPath $cakePath

dotnet tool restore
if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory	
	exit $LASTEXITCODE 
}

dotnet cake --projectName $ensureScriptOutput --rootPath $rootPath --projectPath (Split-Path -Parent $csprojPath) --buildPath $buildPath --packageId  $bootstrapScriptOutput.Id --packageTitle $bootstrapScriptOutput.Title --packageDescription $bootstrapScriptOutput.Description --packageAuthors $bootstrapScriptOutput.Authors

if ($LASTEXITCODE -ne 0) { 
	Set-Location -LiteralPath $currentDirectory
	exit $LASTEXITCODE 
}

Set-Location -LiteralPath $currentDirectory