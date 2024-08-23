<#
.SYNOPSIS
Ensure csproj has all the properties needed
#>
function Confirm-csproj-properties{
    param(
        [Parameter(Mandatory=$true)]
        [string]$filePath
    )

    $ErrorActionPreference = 'Stop'   

    if((Test-Path -Path $csprojPath) -eq $false){
        Write-Host "[Confirm-csproj-properties] Path $csprojPath does not exist" -foregroundColor Red
        exit 1
    }
    Write-Verbose ("[Confirm-csproj-properties] csprojPath: $($csprojPath)")

    # Get csproj
    $csproj = Get-Item -Path $csprojPath
    # Load the XML content of the csproj file
    $xml = [xml](Get-Content $csproj.FullName)
    # Potential missing properties that does not require user input
    $noInputProperties = @(
        @{
            xmlProperty = $xml.Project.PropertyGroup.IsPackable
            name = "IsPackable"
            value = "true"
        },
        # Allows creation of pre-releases versions because the specified version string does not conform to the required format 
        @{
            xmlProperty = $xml.Project.PropertyGroup.GenerateAssemblyInfo
            name = "GenerateAssemblyInfo"
            value = "False"
        },
        @{
            xmlProperty = $xml.Project.PropertyGroup.Deterministic
            name = "Deterministic"
            value = "False"
        }
    )

    $propertyGroup = $xml.Project.PropertyGroup
    $saveFile = $false
    foreach ($row in $noInputProperties) {
        if ($null -eq $row.xmlProperty) {
        $propertyElement = $xml.CreateElement($row.name)
        $propertyElement.InnerText = $row.value
        $propertyGroup.AppendChild($propertyElement)
        $saveFile = $true
        }
    }

    Save-File -filePath $filePath -saveFile $saveFile

    if($saveFile -eq $false)
    {
        Write-Host "All required properties exist in $($csproj.Name)"  
    }
}

<#
.SYNOPSIS
Ensure package.json has all the properties needed
#>
function Confirm-Package-Json-Properties {
    param (
        [string]$filePath,
        [string]$packageId
    )

    Write-Verbose ("[Confirm-Package-Json-Properties] Checking package.json path: $filePath")
    # Check if the file exists
    if (Test-Path $filePath) {
        # Read the content of the file
        $jsonContent = Get-Content $filePath -Raw | ConvertFrom-Json
        $saveFile=$false
        # Check if the "name" property exist
        if (-not $jsonContent.name) {
            # Add the "name" property 
            $jsonContent | Add-Member -MemberType NoteProperty -Name "name" -Value $packageId.ToLower() -Force
            $saveFile = $true
        }
        if (-not $jsonContent.private) {
            # Allow running without an configured NPM_TOKEN : https://github.com/semantic-release/npm/issues/324
            $jsonContent | Add-Member -MemberType NoteProperty -Name "private" -Value $true -Force
            $saveFile = $true
        }
                
        if($saveFile -eq $true){                
            # Convert the JSON object back to JSON format
            $newContent = $jsonContent | ConvertTo-Json -Depth 2
            # Write the new content to the file
            $newContent | Set-Content $filePath
            Write-Host  "One or more properties have been successfully added to package.json"
        }

        $changelogVersion = $jsonContent.dependencies.'@semantic-release/changelog'.Substring(1)
        $execVersion = $jsonContent.dependencies.'@semantic-release/exec'.Substring(1)
        $gitVersion = $jsonContent.dependencies.'@semantic-release/git'.Substring(1)
        $semanticReleaseVersion = $jsonContent.dependencies.'semantic-release'.Substring(1)

        return [PSCustomObject]@{
            changelogVersion = $changelogVersion
            execVersion = $execVersion
            gitVersion = $gitVersion
            semanticReleaseVersion = $semanticReleaseVersion
        }
            
    } else {
        Write-Host "The file package.json doesn't exist."
        exit 1
    }
}

<#
.SYNOPSIS
Copy Git Hooks
#>
function Copy-Git-Hooks {
    param (
        [string]$filePath,
        [string]$includePath,
        [string]$destinationFolder
    )

    Write-Verbose ("[Copy-Git-Hooks] Copying Git Hooks...")
    $xml = [xml](Get-Content $filePath)

    $target = $xml.Project.Target | Where-Object { $_.Name -eq "CopyCakeReleaseGitHooks" }
    if ($null -eq $target) {
        # Si le Target n'existe pas, on le crée et on l'ajoute au projet
        $target = $xml.CreateElement("Target")
        $target.SetAttribute("Name", "CopyCakeReleaseGitHooks")
        $target.SetAttribute("AfterTargets", "AfterBuild")
        $xml.Project.AppendChild($target)
    }

    $xmlGroups = @("//Target[@Name='CopyCakeReleaseGitHooks']/ItemGroup", "//Target[@Name='CopyCakeReleaseGitHooks']/Copy")
    foreach($xmlGroup in $xmlGroups){
        $existingNodes = $xml.SelectNodes($xmlGroup)
        if ($existingNodes.Count -gt 0) {
            foreach ($node in $existingNodes) {
                $node.ParentNode.RemoveChild($node) | Out-Null
            }
        }   
    }

    $itemGroup = $xml.CreateElement("ItemGroup")
    $customFiles = $xml.CreateElement("_CustomFiles")
    $customFiles.SetAttribute("Include", $includePath)
    $itemGroup.AppendChild($customFiles)
    $target.AppendChild($itemGroup)

    $copyElement = $xml.CreateElement("Copy")
    $copyElement.SetAttribute("SourceFiles", "@(_CustomFiles)")
    $copyElement.SetAttribute("DestinationFolder", $destinationFolder)
    $target.AppendChild($copyElement)

    Write-Host "Git Hooks added to $($filePath)"
    Save-File -filePath $filePath -saveFile $true
}

<#
.SYNOPSIS
Ensure .nuspec has all the properties needed
#>
function Confirm-Nuspec-Properties {
    param (
        [string]$filePath
    )
    $xml = [xml](Get-Content $filePath)
    $missingProperties = @()
    $properties = @{
        'id' = $xml.package.metadata.id
        'title' = $xml.package.metadata.title
        'description' = $xml.package.metadata.description
        'authors' = $xml.package.metadata.authors
    }

    $parent = $xml.package.metadata
    $saveFile = $false

    foreach ($property in $properties.GetEnumerator()) {
        if ($null -eq $property.Value) {
            $missingProperties += $property.Key
        }
    }

    if ($missingProperties.Count -gt 0) {
        $saveFile = $true
        Write-Host "The following properties are missing : $($missingProperties -join ', ')"
        Write-Host "Please enter the missing property values:"

        # Prompt the user to enter missing property values
        foreach ($missingProperty in $missingProperties) {
            $value = Read-Host "Enter $($missingProperty)"
            $properties[$missingProperty] = $value
        }

        # Add the missing properties 
        foreach ($missingProperty in $missingProperties) {
            $propertyElement = $xml.CreateElement($missingProperty)
            $propertyElement.InnerText = $properties[$missingProperty]
            $parent.AppendChild($propertyElement)
        }
    } 

    Save-File -filePath $filePath -saveFile $saveFile

    if($saveFile -eq $false){
        Write-Host "All required properties exist in .nuspec"
        Write-Verbose ("[Confirm-Nuspec-Properties] Saving file to: $($filePath)")
    }

    return [PSCustomObject]@{
        Id = '"' + $xml.package.metadata.id + '"'
        Title = '"' + $xml.package.metadata.title + '"'
        Description = '"' + $xml.package.metadata.description + '"'
        Authors = '"' + $xml.package.metadata.authors + '"'
    }
}

function Save-File {
    param (
        [string]$filePath,
        $saveFile
    )
    if($saveFile -eq $true)
    {
        # Save the changes to the csproj file
        $xml.Save($filePath)
        Write-Host "Updated $($filePath)"
    } 
}

<#
.SYNOPSIS
Ensures the path will be absolute
#>
function Use-Absolute-Path {
    param (
        [string]$isRelativeFromPath,
        [string]$path,
        [switch]$isDirectory    
    )

if(([System.IO.Path]::IsPathRooted($path)) -and ($isDirectory.IsPresent))
{
    # Ensures that the last character on the extraction path is the directory separator char.
    if(-not $path.EndsWith([System.IO.Path]::DirectorySeparatorChar.ToString(), [StringComparison]::Ordinal)){
        $path += [System.IO.Path]::DirectorySeparatorChar;
    }
    return $path
}
else 
{
    if ([string]::IsNullOrWhiteSpace($isRelativeFromPath)) {
        return Resolve-Path $path
    } 
    return Resolve-Path -Path (Join-Path -Path $isRelativeFromPath -ChildPath $path)
}
}

function Test-NuSpec-Exists {
    param (
        [string]$nuspecFilePath,
        [string]$defaultPath
    )
    if ([string]::IsNullOrWhiteSpace($nuspecFilePath)) {
        $nuspecPath = Join-Path -Path $rootPath -ChildPath $defaultPath
        if (Test-Path $nuspecPath) {
            $nuspecFilePath = Resolve-Path $nuspecPath
            Write-Verbose ("[Test-NuSpec-Exists] .nuspec path: $nuspecFilePath")
            return $nuspecFilePath
        }
        else {
            Write-Host "no .nuspec found at path ${nuspecPath}"
            exit 1
        }
    }
    return Use-Absolute-Path -path $nuspecFilePath -isRelativeFromPath $cakeReleaseScriptDirectory
}

<#
.SYNOPSIS
 Gets csproj path
#>
function Get-Csproj-Path{
    param (
        [string]$csprojPath
)

if ([string]::IsNullOrWhiteSpace($csprojPath)) {
    $csprojFiles = Get-Files -Path $rootPath -Filter *.csproj -Exclude node_modules | Where-Object { $_.Name -notmatch "\.Tests\.csproj$" }
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
Write-Verbose ("[Get-Csproj-Path] csprojPath: $csprojPath")
return $csprojPath
}

# Ensures parameter value has been assigned
function Confirm-String-Parameter {
    param (
        [string]$param,
        [string]$prompt
    )
    if ([string]::IsNullOrWhiteSpace($param)) {
        $param = read-host -Prompt $prompt
    } 
    return $param
}

<#
.SYNOPSIS
Formats path with double backslash
#>
function Format-With-Double-Backslash{
    param (
        [string]$string
    )
    for ($i = 0; $i -lt $string.Length; $i++) {
        # If the character is a backslash
        if ($string[$i] -eq '\') {
            # If the backslash is followed by another backslash
            if (($i + 1) -lt $string.Length -and $string[$i + 1] -eq '\') {
                # Add the two backslashes to the result and skip the next character
                $result += '\\'
                $i++
            } else {
                # Add a double backslash to the result
                $result += '\\'
            }
        } else {
            # Add the current character to the result
            $result += $string[$i]
        }
    }
    return $result
}

<#
.SYNOPSIS
Get files excluding specific folder in the search
#>
function Get-Files {
    param (
        [string]$Path,
        [string]$Filter,
        [string]$Exclude
    )

    try {
        $items = Get-ChildItem -Path $Path -ErrorAction Stop
        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                if ($item.Name -ne $Exclude) {
                    Get-Files -Path $item.FullName -Filter $Filter -Exclude $Exclude
                }
            }
            else {
                if ($item.Name -like $Filter) {
                    $item
                }
            }
        }
    }
    catch {
        Write-Warning "Unable to access path: $Path. Error: $_"
    }
}

<#
.SYNOPSIS
Gets relative path from absolute paths
#>
function Get-Relative-Path-From-Absolute-Paths {
    param (
        [string]$fromPath,    # Chemin absolu du dossier d'origine
        [string]$toPath       # Chemin absolu du dossier cible
    )

    # Normalise les chemins (supprime les barres obliques inverses finales)
    $fromPath = (Get-Item -LiteralPath $fromPath).FullName.TrimEnd('\')
    $toPath = (Get-Item -LiteralPath $toPath).FullName.TrimEnd('\')

    # Sépare les chemins en segments en utilisant le caractère [System.IO.Path]::DirectorySeparatorChar
    $separator = [System.IO.Path]::DirectorySeparatorChar
    $fromParts = $fromPath -split [Regex]::Escape($separator)
    $toParts = $toPath -split [Regex]::Escape($separator)

    # Trouve le premier segment différent entre les deux chemins
    $commonLength = 0
    for ($i = 0; $i -lt [math]::Min($fromParts.Length, $toParts.Length); $i++) {
        if ($fromParts[$i] -ne $toParts[$i]) {
            break
        }
        $commonLength++
    }

    # Nombre de ".." à ajouter pour remonter dans l'arborescence depuis le dossier d'origine
    $upCount = $fromParts.Length - $commonLength
    $relativePath = (".." + $separator) * $upCount

    # Ajoute les segments du chemin cible restants
    $relativePath += ($toParts[$commonLength..($toParts.Length - 1)] -join $separator)

    # Retire la barre oblique inverse finale si elle est présente
    return $relativePath.TrimEnd($separator)
}


<#
.SYNOPSIS
Finds .git folder relative path
#>
function Find-GitFolder-Relative-Path {
    param (
        [string]$currentPath = (Get-Location).Path,
        [string]$relativePath = "",
        [string]$fromAbsolutePath
    )

    $combinedPath = Join-Path -Path $currentPath -ChildPath $relativePath

    if (Test-Path -Path (Join-Path -Path $combinedPath -ChildPath ".git")) {
        $absolutePath = Join-Path ($combinedPath | Resolve-Path) ".git/hooks"
        return Get-Relative-Path-From-Absolute-Paths -toPath $absolutePath -fromPath $fromAbsolutePath
    }

    $parentPath = Split-Path -Path $combinedPath -Parent
    if ($parentPath -eq $combinedPath) {
        return $null
    }

    return Find-GitFolder-Relative-Path -currentPath $parentPath -relativePath (Join-Path ".." $relativePath) -fromAbsolutePath $fromAbsolutePath
}


$path = "c:\temp\test"

$filename = "test.zip"
<#
.SYNOPSIS
Creates folders structure if it does not exist
#>
function Confirm-Folder-Structure {
    param (
        [string]$path,
        [string]$filename
    )
    #if no folder exists, create one

    if(-not (test-path $path)){
        New-Item -Path $path -ItemType Directory
    }

    #if the file already exists, remove it
    if(test-path "$path\$filename"){
        remove-item -Path "$path\$filename" -Force
    }
}