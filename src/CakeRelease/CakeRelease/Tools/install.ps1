param($MSBuildThisFileDirectory, # The package build folder
$MSBuildProjectDirectory, # The project Directory
$MSBuildProjectName, # The project Name
$MSBuildProjectFile) # The project File Name (.csproj)

# Write-Host "MSBuildThisFileDirectory: $MSBuildThisFileDirectory"
# Write-Host "MSBuildProjectDirectory: $MSBuildProjectDirectory"
# Write-Host "MSBuildProjectName: $MSBuildProjectName"
# Write-Host "MSBuildProjectFile: $MSBuildProjectFile"

function Update-Config-JsonFile {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$NewObject,   # L'objet à ajouter ou modifier dans le fichier JSON

        [Parameter(Mandatory=$true)]
        [string]$FilePath        # Chemin du fichier JSON à modifier
    )

    $objectList = @()

    if (Test-Path -Path $FilePath) {
        try {
            $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
            $objectList = @($jsonContent)
        } catch {
            Write-Host "Error while reading JSON file: $_"
            return
        }
    }
    $existingObject = $objectList | Where-Object { $_.Name -eq $NewObject.Name }
    if ($existingObject) {
        foreach ($property in $NewObject.Keys) {
            $existingObject.$property = $NewObject.$property
        }
    } else {
        $objectList += [PSCustomObject]$NewObject
    }
    $json = $objectList | ConvertTo-Json -Depth 10 #-Compress
    try {
        $json | Out-File -FilePath $FilePath -Encoding UTF8
        Write-Host "Fichier JSON mis à jour avec succès à l'emplacement: $FilePath"
    } catch {
        Write-Host "Error while saving JSON file: $_"
    }
}

# Create or update Tool Manifest
$manifestPath =  (Join-Path -Path $MSBuildProjectDirectory -ChildPath "..") | Resolve-Path
Write-Host "manifestPath: $manifestPath"
Set-Location -LiteralPath $manifestPath
dotnet new tool-manifest
dotnet tool install Cake.Tool --version 4.0.0

$packageDirectory = (Join-Path -Path $MSBuildThisFileDirectory -ChildPath "..") | Resolve-Path

# Adding current project configuration
$projectSettings = @{
    "Name" = "$MSBuildProjectName"
    "ProjectDirectory" = "$MSBuildProjectDirectory"
    "PackageDirectory" = "$packageDirectory"
    "VersionNumber" = "$(Split-Path $packageDirectory -Leaf)"
}

$cakeReleaseSettingsPath = Join-Path -Path $MSBuildProjectDirectory -ChildPath "../.config/CakeRelease.settings.json"
Write-Host "cakeReleaseSettingsPath: $cakeReleaseSettingsPath"
Write-Host "projectSettings: $($projectSettings)"

Update-Config-JsonFile -NewObject $projectSettings -FilePath $cakeReleaseSettingsPath
# $projectSettings.Name="test"
# Update-Config-JsonFile -NewObject $projectSettings -FilePath $cakeReleaseSettingsPath
