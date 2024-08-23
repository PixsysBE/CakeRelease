param($installPath, $toolsPath, $package, $project)

# function Copy-New-Item {
#     param (
#         [string]$Path,
#         [string]$Destination      
#     )
  
#     If (-not (Test-Path $Destination)) {
#       New-Item -ItemType File -Path $Destination -Force
#     } 
#     Copy-Item -Path $Path -Destination $Destination
#   }

# function Update-JsonFile {
#     param (
#         [Parameter(Mandatory=$true)]
#         [hashtable]$NewObject,   # L'objet à ajouter ou modifier dans le fichier JSON

#         [Parameter(Mandatory=$true)]
#         [string]$FilePath        # Chemin du fichier JSON à modifier
#     )

#     # Initialiser la liste d'objets
#     $objectList = @()

#     # Vérifie si le fichier existe
#     if (Test-Path -Path $FilePath) {
#         # Charge le contenu du fichier JSON existant
#         try {
#             $jsonContent = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
#             $objectList = @($jsonContent) # Assure que c'est un tableau d'objets
#         } catch {
#             Write-Host "Erreur lors de la lecture du fichier JSON : $_"
#             return
#         }
#     }

#     $existingObject = $objectList | Where-Object { $_.Name -eq $NewObject.Name }

#     if ($existingObject) {
#         foreach ($property in $NewObject.Keys) {
#             $existingObject.$property = $NewObject.$property
#         }
#     } else {
#         $objectList += [PSCustomObject]$NewObject
#     }

#     $json = $objectList | ConvertTo-Json -Depth 10 #-Compress

#     try {
#         $json | Out-File -FilePath $FilePath -Encoding UTF8
#         Write-Host "Fichier JSON mis à jour avec succès à l'emplacement: $FilePath"
#     } catch {
#         Write-Host "Erreur lors de la sauvegarde du fichier JSON : $_"
#     }
# }

# # # Get the current directory
# $currentDirectory = Get-Location

# Write-Host "installPath: $installPath" 
# Write-Host "toolsPath: $toolsPath" 
# Write-Host "currentDirectory: $currentDirectory" 
# $projectDirectory = Split-Path -Parent $project.FullName
# Write-Host "projectDirectory: $projectDirectory"

# # Create or update Tool Manifest
# $manifestPath =  (Join-Path -Path $projectDirectory -ChildPath "..") | Resolve-Path
# Write-Host "manifestPath: $manifestPath"
# Set-Location -LiteralPath $manifestPath
# dotnet new tool-manifest
# dotnet tool install Cake.Tool --version 4.0.0


# # Adding current project configuration
# $projectSettings = @{
#     "Name" = $project.Name
#     "ProjectDirectory" = $project.FullName | Split-Path -Leaf
#     "PackageDirectory" = $installPath
# }

# $cakeReleaseSettingsPath = Join-Path -Path $projectDirectory -ChildPath "../.config/CakeRelease.settings.json"
# Write-Host "cakeReleaseSettingsPath: $cakeReleaseSettingsPath"

# Update-JsonFile -NewObject $projectSettings -FilePath $cakeReleaseSettingsPath







# $overrideFiles = @(".build\CakeRelease\cakerelease.ps1",
#                    ".build\CakeRelease\Cake\build.cake",
#                    ".build\CakeRelease\Git\Hooks\commit-msg",
#                    ".build\CakeRelease\Powershell\cakerelease.functions.ps1",
#                    ".build\CakeRelease\Powershell\cakerelease.settings.ps1",
#                    ".build\CakeRelease\Semantic\Config\github.js",
#                    ".build\CakeRelease\Semantic\Config\main.js",
#                    ".build\CakeRelease\Semantic\Config\nuget.js",
#                    ".build\CakeRelease\Semantic\Scripts\publishPackageToNuget.sh",
#                    ".config\dotnet-tools.json",
#                    ".config\nuspec.sample"
#                   )

# # Copy root files
# Copy-New-Item -Path (Join-Path -Path $installPath -ChildPath "./package.json") -Destination $currentDirectory

# # Copy folder files
# $folders = @(".build",".config")
# foreach($folder in $folders)
# {
#     $sourcePath = Join-Path -Path $installPath -ChildPath $folder
#     $targetBasePath = Join-Path -Path $currentDirectory -ChildPath $folder
#     $sourceFiles = Get-ChildItem -Path $sourcePath -File -Recurse
#     foreach($sourceFile in $sourceFiles)
#     {
#         $sourceRelativePath = $sourceFile.FullName.Remove(0,($sourcePath.length))
#         $targetPath = Join-Path -Path $targetBasePath -ChildPath $sourceRelativePath
#         # Write-Host $sourceFile.FullName
#         if(Test-Path -Path $targetPath){
#             if($overrideFiles -contains ($folder + $sourceRelativePath))
#             {
#                 Write-Host "${sourceRelativePath} already exists but will be overriden"  -ForegroundColor Green
#                 Copy-Item -Path $sourceFile.FullName -Destination $targetPath -Force
#             } else {
#                 Write-Host "${sourceRelativePath} already exists, skipping..."  -ForegroundColor Red -BackgroundColor Yellow
#             }
#         }
#         else {
#             Write-Host "Copying ${targetPath}..."  
#             Copy-New-Item -Path $sourceFile.FullName -Destination $targetPath -Recurse -Force
#         }
#     }
# }