$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

$rootPathFolder = "../.."
# Get root path (usually containing sln file)
$rootPath = Use-Absolute-Path (Join-Path -Path $launcherScriptDirectory -ChildPath $rootPathFolder)
Write-Verbose ("rootPath: $rootPath")
$semanticConfigPath = Join-Path -Path $cakeReleaseScriptDirectory -ChildPath ".\Semantic\Config\"
Write-Verbose ("semanticConfigPath: $semanticConfigPath")
$mainConfigPath = Join-Path -Path $semanticConfigPath -ChildPath ".\main.js"
Write-Verbose ("mainConfigPath: $mainConfigPath")
$semanticScriptsPath = Join-Path -Path $cakeReleaseScriptDirectory -ChildPath ".\Semantic\Scripts\"
Write-Verbose ("semanticScriptsPath: $semanticScriptsPath")
$semanticDirectory = Join-Path -Path $launcherScriptDirectory -ChildPath ".\Semantic\"
Write-Verbose ("semanticDirectory: $semanticDirectory")
$semanticReleaseRcFileName = ".releaserc.js"
$packageJsonPath = Join-Path -Path $semanticDirectory -ChildPath ".\package.json"
Write-Verbose ("packageJsonPath: $packageJsonPath")
$env:PUBLISH_PACKAGE_TO_NUGET_SCRIPT = Format-With-Double-Backslash -string ".\Scripts\publishPackageToNuget.sh"

# Semantic Release config file
$githubConfig = $null
if($createGithubRelease.IsPresent)
{
	$githubConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "github.js"
	$githubConfig = Get-Content -Path $githubConfigPath -Raw
}
Write-Verbose ("githubConfig: $githubConfig")

$nugetConfig = $null
if($publishToNuget.IsPresent -or (-not [string]::IsNullOrWhiteSpace($publishToSource))){
	$nugetConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "nuget.js"
	$nugetConfig = Get-Content -Path $nugetConfigPath -Raw
}
Write-Verbose ("nugetConfig: $nugetConfig")

# .build folder path
$buildPath = ""
if(-not $autoBuild.IsPresent)
{
	$buildPath = "../"
}
Write-Verbose ("buildPath: $buildPath")

# Cake build
$cakeDirectory = Join-Path -Path $cakeReleaseScriptDirectory -ChildPath ".\Cake"
Write-Verbose ("cakeDirectory: $cakeDirectory")
$buildCakePath = (Join-Path -Path $cakeDirectory -ChildPath ".\build.cake") | Resolve-Path

# Get nuspecFile path
$nuspec = ".nuspec"
if($autoBuild.IsPresent){
    $nuspec = "autoBuild.nuspec"
}
Write-Verbose ("nuspec: $nuspec")

$nuspecFilePath = Test-NuSpec-Exists -nuspecFilePath $nuspecFilePath -defaultPath ".\.config\${nuspec}"
Write-Verbose ("nuspecFilePath: $nuspecFilePath")

# Git Hooks
$gitHooksFolder = (Join-Path -Path $launcherScriptDirectory -ChildPath  ".\Git\Hooks\") | Resolve-Path

$csprojPath = Get-Csproj-Path -csprojPath $csprojPath
$csprojTargetGitHooksCommitMsgPath = Get-Relative-Path-From-Absolute-Paths -fromPath (Split-Path -Parent $csprojPath) -toPath "${gitHooksFolder}commit-msg"
$csprojTargetGitHooksCommitMsgDestinationFolder = Find-GitFolder-Relative-Path -fromAbsolutePath (Split-Path -Parent $csprojPath)
if ($null -eq $csprojTargetGitHooksCommitMsgDestinationFolder) {
    Write-Host ".git folder not found" -ForegroundColor Red
	exit 1
}
