$env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'

# Relative paths from PSScriptRoot
$rootPathFolder = "../.."
$rootPath = Resolve-Path (Join-Path -Path $psBuildDirectory -ChildPath $rootPathFolder)
$semanticConfigPath = Join-Path -Path $psBuildDirectory -ChildPath ".\Semantic\Config\"
$mainConfigPath = Join-Path -Path $semanticConfigPath -ChildPath ".\main.js"
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
$cakePath = Join-Path -Path $psBuildDirectory -ChildPath ".\Cake"

# Get nuspecFile path
$nuspec = ".nuspec"
if($autoBuild.IsPresent){
    $nuspec = "release.nuspec"
}

$nuspecFilePath = Test-NuSpec-Exists -nuspecFilePath $nuspecFilePath -defaultPath ".\.build\CakeRelease\Package\${nuspec}" -verbose:$verbose

$csprojTargetGitHooksCommitMsgPath = ".build\CakeRelease\Git\Hooks\commit-msg"
$csprojTargetGitHooksCommitMsgDestinationFolder = "./../../../.git/hooks"