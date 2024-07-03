$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

# Relative path from PSScriptRoot
$rootPathFolder = "../.."

$rootPath = Resolve-Path (Join-Path -Path $cakeReleaseDirectory -ChildPath $rootPathFolder)
$semanticConfigPath = Join-Path -Path $cakeReleaseDirectory -ChildPath ".\Semantic\Config\"
$mainConfigPath = Join-Path -Path $semanticConfigPath -ChildPath ".\main.js"
$releaseConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "../.releaserc.js"
$packageJsonPath = Join-Path -Path $cakeReleaseDirectory -ChildPath "../../package.json"

# Semantic Release config file
$githubConfig = $null
if($createGithubRelease.IsPresent)
{
	$githubConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "github.js"
	$githubConfig = Get-Content -Path $githubConfigPath -Raw
}

$nugetConfig = $null
if($publishToNuget.IsPresent -or (-not [string]::IsNullOrWhiteSpace($publishToSource))){
	$nugetConfigPath = Join-Path -Path $semanticConfigPath -ChildPath "nuget.js"
	$nugetpublishCmd = $null
	if(-not [string]::IsNullOrWhiteSpace($publishToSource)){
		#$nugetpublishCmd = ".\\Scripts\\publishPackageToSource.sh $`{process.env.PUBLISH_PACKAGE_TO_NUGET_SOURCE`}; "
		$nugetpublishCmd = "dotnet nuget push .\Artifacts\*.nupkg -s $`{process.env.PUBLISH_PACKAGE_TO_NUGET_SOURCE`}; "
	}
	if($publishToNuget.IsPresent)
	{
		$nugetpublishCmd += "dotnet nuget push .\Artifacts\*.nupkg -k $`{process.env.NUGET_TOKEN`} -s https://api.nuget.org/v3/index.json;"
	}
	$nugetConfig = (Get-Content -Path $nugetConfigPath -Raw) -replace "{%NUGETPUBLISHCMD%}", $nugetpublishCmd 
}

# .build folder path
$buildPath = ""
if(-not $autoBuild.IsPresent)
{
	$buildPath = "../"
}

# Cake build
$cakePath = Join-Path -Path $cakeReleaseDirectory -ChildPath ".\Cake"

# Get nuspecFile path
$nuspec = ".nuspec"
if($autoBuild.IsPresent){
    $nuspec = "release.nuspec"
}

$nuspecFilePath = Test-NuSpec-Exists -nuspecFilePath $nuspecFilePath -defaultPath ".\.build\CakeRelease\Package\${nuspec}" -verbose:$verbose

# Git Hooks
$csprojTargetGitHooksCommitMsgPath = ".build\CakeRelease\Git\Hooks\commit-msg"
$csprojTargetGitHooksCommitMsgDestinationFolder = "./../../../.git/hooks"