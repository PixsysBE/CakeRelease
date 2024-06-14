﻿param($installPath, $toolsPath, $package, $project)

function Copy-New-Item {
    param (
        [string]$Path,
        [string]$Destination      
    )
  
    If (-not (Test-Path $Destination)) {
      New-Item -ItemType File -Path $Destination -Force
    } 
    Copy-Item -Path $Path -Destination $Destination
  }

# Get the current directory
$currentDirectory = Get-Location

$overrideFiles = @(".build\CakeRelease\Semanticbuild.ps1",
                   ".build\CakeRelease\Cake\build.cake",
                   ".build\CakeRelease\Git\Hooks\commit-msg",
                   ".build\CakeRelease\Powershell\bootstrapRelease.ps1",
                   ".build\CakeRelease\Semantic\Config\github.js",
                   ".build\CakeRelease\Semantic\Config\main.js",
                   ".build\CakeRelease\Semantic\Scripts\publishPackageToNuget.sh",
                   ".config\dotnet-tools.json"
                  )

$folders = @("/.build","/.config")
foreach($folder in $folders)
{
    $sourcePath = Join-Path -Path $installPath -ChildPath $folder
    $targetPath = Join-Path -Path $currentDirectory -ChildPath $folder
    $sourceFiles = Get-ChildItem -Path $sourcePath -File -Recurse
    foreach($sourceFile in $sourceFiles)
    {
        $sourceRelativePath = $sourceFile.FullName.Remove(0,($sourcePath.length))
        $targetPath = Join-Path -Path $targetPath -ChildPath $sourceRelativePath
        $exists = Test-Path -Path $targetPath
        # Write-Host $sourceFile.FullName
        if($exists -eq $true){
            if($overrideFiles -contains $sourceRelativePath)
            {
                Write-Host "${sourceRelativePath} already exists but will be overriden"  -ForegroundColor Green
                Copy-Item -Path $sourceFile.FullName -Destination $targetPath -Force
            } else {
                Write-Host "${sourceRelativePath} already exists, skipping..."  -ForegroundColor Red -BackgroundColor Yellow
            }
        }
        else {
            Write-Host "Copying ${targetPath}..."  
            Copy-New-Item -Path $sourceFile.FullName -Destination $targetPath -Recurse -Force
        }
        # Write-Host $targetPath $exists #sourceRelativePath
    }
}