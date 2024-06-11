param (
    [string]$rootPath,
    [string]$csprojPath
)

# Get root path
# $rootPath = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "../../..")
# Write-Host "rootPath: ${rootPath}"

# Get csproj
# if ([string]::IsNullOrWhiteSpace($csprojPath)) {
#     $csprojFiles = Get-ChildItem -Path $rootPath -Recurse -Filter *.csproj | Where-Object { $_.Name -notmatch "\.Tests\.csproj$" }
#     # Check if only one csproj file exists
#     if ($csprojFiles.Count -ne 1)
#     {
#         Write-Host "Found $($csprojFiles.Count) csproj files. Please specify which csproj file to use"   
#         exit 1
#     }
#     else {
#         $csproj = $csprojFiles[0]
#     }
# } else {
    $csproj = Get-Item -Path $csprojPath
# }

#   Load the XML content of the csproj file
    $xml = [xml](Get-Content $csproj.FullName)

    #### PART 1: Ensure project properties exist #####
    $missingProperties = @()
    $properties = @{
        'PackageId' = $xml.Project.PropertyGroup.PackageId
        'Title' = $xml.Project.PropertyGroup.Title
        'Authors' = $xml.Project.PropertyGroup.Authors
        'Company' = $xml.Project.PropertyGroup.Company
        'Description' = $xml.Project.PropertyGroup.Description
    }

    $propertyGroup = $xml.Project.PropertyGroup
    $saveFile = 0

    foreach ($property in $properties.GetEnumerator()) {
        if ($null -eq $property.Value) {
            $missingProperties += $property.Key
        }
    }

    if ($missingProperties.Count -gt 0) {
        $saveFile = 1
        Write-Host "The following properties are missing from $($csproj.Name): $($missingProperties -join ', ')"
        Write-Host "Please enter the missing property values:"

        # Prompt the user to enter missing property values
        foreach ($missingProperty in $missingProperties) {
            $value = Read-Host "Enter $($missingProperty)"
            $properties[$missingProperty] = $value
        }

        # Add the missing properties to the csproj XML
        foreach ($missingProperty in $missingProperties) {
            $propertyElement = $xml.CreateElement($missingProperty)
            $propertyElement.InnerText = $properties[$missingProperty]
            $propertyGroup.AppendChild($propertyElement)
        }
    } 
        # Potential missing properties that does not require user input
        $noInputProperties = @(@("IsPackable", $xml.Project.PropertyGroup.IsPackable , "true"), 
        @("PackageReadmeFile", $xml.Project.PropertyGroup.PackageReadmeFile, "README.md"), 
        @("GenerateAssemblyInfo", $xml.Project.PropertyGroup.GenerateAssemblyInfo, "false"), 
        @("Deterministic", $xml.Project.PropertyGroup.Deterministic, "false")
        )

        foreach ($row in $noInputProperties) {
            if ($null -eq $row[1]) {
            $propertyElement = $xml.CreateElement($row[0])
            $propertyElement.InnerText = $row[2]
            $propertyGroup.AppendChild($propertyElement)
            $saveFile = 1
            }
        }

    ##### PART 2 : Ensure README is included

       # Ensure ItemGroup exists
       $itemGroup = $xml.Project.ItemGroup
       if ($null -eq $itemGroup) {
           $itemGroup = $xml.CreateElement("ItemGroup")
           $xml.Project.AppendChild($itemGroup)
       }

       # Check if the specified content already exists
       $readMeItem = $xml.Project.SelectNodes("//ItemGroup/None[@Include='README.md']")
       if ($readMeItem.Count -eq 0) {
       # The specified content doesn't exist, so add it
       $newItem = $xml.CreateElement("None")
       $newItem.SetAttribute("Include", "README.md")

       $packElement = $xml.CreateElement("Pack")
       $packElement.InnerText = "True"
       $newItem.AppendChild($packElement)

       $packagePathElement = $xml.CreateElement("PackagePath")
       $packagePathElement.InnerText = "\"
       $newItem.AppendChild($packagePathElement)

       $itemGroup.AppendChild($newItem)

       $saveFile =1
       Write-Host "Including README.md to $($csproj.Name)"
    }

    ##### PART 3 : Copy Git Hooks #####

        # Ensure Target exists
        $target = $xml.Project.Target
        if ($null -eq $target) {
            $target = $xml.CreateElement("Target")
            $target.SetAttribute("Name", "CopyCustomContent")
            $target.SetAttribute("AfterTargets", "AfterBuild")
            $xml.Project.AppendChild($target)
        }

       $existingItemGroup = $xml.Project.SelectNodes("//Target[@Name='CopyCustomContent']/ItemGroup/_CustomFiles[@Include='.build\CakeRelease\Git\Hooks\commit-msg']")
       if ($existingItemGroup.Count -eq 0) {
       # The specified content doesn't exist, so add it
       $itemGroup = $xml.CreateElement("ItemGroup")
       $customFiles = $xml.CreateElement("_CustomFiles")
       $customFiles.SetAttribute("Include", ".build\CakeRelease\Git\Hooks\commit-msg")
       $itemGroup.AppendChild($customFiles)
       $target.AppendChild($itemGroup)

       $copyElement = $xml.CreateElement("Copy")
       $copyElement.SetAttribute("SourceFiles", "@(_CustomFiles)")
       $copyElement.SetAttribute("DestinationFolder", "./../../../.git/hooks")
       $target.AppendChild($copyElement)

       # Save the changes to the csproj file
       $saveFile=1
       Write-Host "Git Hooks added to $($csproj.Name)"
    }

    if($saveFile -eq 1)
    {
        # Save the changes to the csproj file
        $xml.Save($csproj.FullName)
        Write-Host "Updated $($csproj.Name)"
    } else{
        Write-Host "All required properties exist in $($csproj.Name)"  
    }

    #### PART 4 : Check package.json #####
    # Path to the package.json file
    # $jsonPath = Get-ChildItem -Path (Split-Path -Parent $csproj.FullName) -Recurse -Filter "package.json"
    Write-Host "rootPath:" $rootPath
    $jsonPath = Join-Path -Path $rootPath -ChildPath "package.json"

    # Check if the file exists
    if (Test-Path $jsonPath) {
        # Read the content of the file
        $jsonContent = Get-Content $jsonPath -Raw | ConvertFrom-Json
        $saveJson=$false
        # Check if the "name" property exist
        if (-not $jsonContent.name) {
            # Add the "name" property 
            $jsonContent | Add-Member -MemberType NoteProperty -Name "name" -Value $xml.Project.PropertyGroup.PackageId.ToLower() -Force
            $saveJson = $true
        }
        if (-not $jsonContent.private) {
            # Allow running without an configured NPM_TOKEN : https://github.com/semantic-release/npm/issues/324
            $jsonContent | Add-Member -MemberType NoteProperty -Name "private" -Value $true -Force
            $saveJson = $true
        }
            
        if($saveJson -eq $true){                
            # Convert the JSON object back to JSON format
            $newContent = $jsonContent | ConvertTo-Json -Depth 2

            # Write the new content to the file
            $newContent | Set-Content $jsonPath
            Write-Host  "One or more properties have been successfully added to package.json"
        }
        
    } else {
        Write-Host "The file package.json doesn't exist."
        return 1
    }

return $xml.Project.PropertyGroup.PackageId